# app/jobs/transcribe_chunk_job.rb
require 'open3'
require 'stringio' # Required for StringIO.new

class TranscribeChunkJob < ApplicationJob
  include TranscriptionSorting
  queue_as :transcription_heavy

  def perform(chunk_id)
     puts "DEBUG: RUNNING NEW VERSION OF TranscribeChunkJob [9-20]"
     chunk =  TranscriptionChunk.includes(transcription_job: :recording).find(chunk_id)
    job = chunk.transcription_job
    recording =  job.recording
    job.update!(started_at: Time.current, status: :processing) if job.started_at.nil?
    @config = Rails.application.credentials.dig(Rails.env.to_sym, :whisper)

    # 1. Update statuses
    chunk.running!
   

    # 2. Transcribe
    prompt = recording.title || "" 
    transcript_text = run_whisper(chunk.file_path, prompt)
    recording.log_status("Processing chunk #{chunk.id} at 550% CPU...")
    # 3. Save chunk text
    txt_path = chunk.file_path.gsub(".wav", ".txt")
    File.write(txt_path, transcript_text)
    chunk.completed!
    
    # 1. Check for Finalization  Since threads:  this is 100% safe from race conditions
    # THE GUARD: If others are still grinding, we stop here.
     
     return unless job.all_chunks_complete?
     
     # 2. THE SCRIBE: Build the string (Logic separate from save)
     full_text = assemble_transcript(job)
     
     # 3. THE ARCHITECT: Save to S3 and Update DB
     bank_in_active_storge(full_text, recording)
     Rails.logger.debug "\n\n after. bank_in_active_storge(full_text, recording)\n\n"
     Rails.logger.debug "\n\n recording transcription status #{recording.transcription_status}\n\n"
     finalize_recording_data(job)
     Rails.logger.debug "\n\nafter finalize_recording_data(job)\n\n"
     # 6. THE JANITOR (Cleanup & Mark Job Done)
      cleanup_workspace(job)
     #finalize_transcription(job)
     Rails.logger.debug "\n\nafter cleanup_workspace(job)\n\n"
     
     
     
     
  rescue StandardError => e
    Rails.logger.error "\n\n chunk_id #{chunk_id} error message #{e.message}\n\n"
    
    transcription_chunk =  TranscriptionChunk.includes(transcription_job: :recording).find(chunk_id)
    transcription_job = transcription_chunk&.transcription_job
    finalize_failed_job(transcription_job, chunk_id,e.message)
    cleanup_workspace(transcription_job) 
    raise e 
  end

  private
  
  def finalize_failed_job(transcription_job, chunk_id, error_message)
    recording = transcription_job&.recording
  
    # Log it early so you have the trail
    recording&.log_status("[MUSCLE][Error] CHUNK #{chunk_id}: #{error_message}")

    # Wrap in a transaction to keep data in sync
    transcription_job.transaction do
      transcription_job.update!(status: :failed, error_message: error_message)
      recording&.update!(transcription_status: :failed)
    
      # Cleans up the partial work
      transcription_job.transcription_chunks.destroy_all
    end
  end
  
  def run_whisper(path, prompt)
    raise "Whisper Model not found at: #{@config[:model_path]}" unless File.exist?(@config[:model_path])

    args = [
      @config[:bin_path], 
      "--model", @config[:model_path],
      "--file", path, 
      "--language", "en", 
      "--no-timestamps",
      "--threads", "6", 
      "--prompt", prompt,
      "--max-context", "64",
      "--split-on-word"
    ]

    stdout, stderr, status = Open3.capture3(*args)
    status.success? ? stdout.strip : raise("Whisper Exit #{status.exitstatus}: #{stderr}")
  end
  
  def assemble_transcript(job)
    final_transcript = []
    grouped_chunks = job.transcription_chunks.completed.group_by(&:original_filename)
  
    sort_by_track_number(grouped_chunks.keys).each do |filename|
      final_transcript << "\n** Source File: #{filename} **\n"
    
      grouped_chunks[filename].sort_by(&:start_time).each do |chunk|
        txt_path = chunk.file_path.gsub(".wav", ".txt")
        timestamp = Time.at(chunk.start_time).utc.strftime("%M:%S")
      
        content = File.exist?(txt_path) ? File.read(txt_path).strip : "[MISSING SEGMENT: #{timestamp}]"
        final_transcript << "[#{timestamp}] #{content}"
      end
    end
    final_transcript.join("\n\n")
  end
  
  def finalize_job(status)
    end_time = Time.current
    processing_time = (end_time - @job_record.started_at).to_i
  
    # Calculate Efficiency Ratio
    if @recording.file_length.to_i > 0
      ratio = (@recording.file_length.to_f / processing_time).round(2)
      log "Final Efficiency: #{ratio}x real-time speed."
    end
 
    @job_record.update!(
      ended_at: end_time, 
      duration_seconds: processing_time, 
      status: status
    )

      
    

    # Phase 3 Cleanup
    Turbo::StreamsChannel.broadcast_remove_to(
      "transcription_monitor_channel",
      target: "transcription_monitor_job_recording_#{@recording.id}"
    )
    @recording.transcription_logs.delete_all
    @job_record.broadcast_to_admin_page
    puts "transcription complete"
  end
  
  def finalize_recording_data(job)
    recording = job.recording
  
    # 1. GENERATE STATISTICS
    # Use the first chunk's 'running' timestamp to get the actual start of work
    start_time = job.started_at # this is when actual transcription started
    end_time = Time.current
    total_seconds = (end_time - start_time).to_i
    file_length = job.transcription_chunks.sum(:duration)
  
    # Speed calculation: Audio Length / Processing Time
    # e.g., 600s audio / 60s processing = 10.0x speed
    speed = (file_length / total_seconds).round(1) rescue 0
    
   
  
    recording.update!(
      transcribed_at: end_time,
      file_length: file_length
    )

    # Log the stats to your Web Window
    recording.log_status("Architect: Finished in #{total_seconds}s (Speed: #{speed}x). All data synced to S3.")
  end
  
  def cleanup_workspace(job)
    temp_dir = Rails.root.join("tmp", "transcription_#{job.id}")
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  
   
    Turbo::StreamsChannel.broadcast_remove_to(
      "transcription_monitor_channel",
      target: "transcription_monitor_job_recording_#{@recording.id}"
    )
    job.recording.log_status("Success: Transcription complete. Workspace clean.")
  end
  
 

  
  def bank_in_active_storge(full_text, recording)
     recording.log_status("Banker: Depositing final transcript to S3...")
    
    custom_key = recording.custom_key_for_transcript
    Rails.logger.debug "\n\nIn the bank do we get into the vault?\n\n"
    
    content = "\n** filename ** #{custom_key}\n\n"
    content << recording_details(recording) + "\n" 
    content << "\n #### Transcript start ####\n\n"
    content << full_text
    content << "\n\n#### Transcript end ####\n\n"

    Rails.logger.debug "\n\nbegin transaction save to active storage update database\n\n"
    
    begin
      Recording.transaction do
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new(content),
          filename: custom_key,
          content_type: "text/plain",
          key: custom_key,
          service_name: :raw_transcripts 
        )
      
        recording.assign_attributes(transcription_status: "completed", raw_transcript: blob)
        recording.save!
      
        # FOR TESTING ROLLBACK
       raise "Testing Rollback one"
      end
  
      # SUCCESS PATH: This only runs if transaction COMMITS
      recording.log_status("Banker: Deposit confirmed. Asset is secure.")
  
    rescue => e
      # ERROR PATH: This catches the "Testing Rollback one"
      # We use &. just in case the recording object got disconnected
      
      Rails.logger.debug("[Error] bank_in_active_storge [9-30]")
      recording&.log_status("Caught error: #{e.message}")
      
      # RE-RAISE: Send it back to 'perform'
      raise e 
    end
  

      
      
  end
  
  
  
  def recording_details(recording)
    details = "#### Metadata start ####\n\n"
    # Added safe navigation &.
    (details << "** Course title **\n#{recording.happening.happenable&.title}\n") if recording.happening.type == "Meet" 
    details << "** Happening title **\n#{recording.happening.title}\n"
    details << "** Recording title **\nS#{recording.number} #{recording.title}\n"
    details << "** start time **\n#{recording.start_datetime.to_fs(:long)}\n"
    details << "** Speakers **\n#{recording.speakers.joins(:contributions).group('speakers.id').order('BOOL_OR(contributions.main) DESC','speakers.created_at ASC').pluck(:stage_name).join(', ')}\n"
    details << "** Write-up **\n#{recording.writeup.to_plain_text.strip}\n"
    details << "\n#### Metadata end ####\n\n"
    details
  end
  
  
end
