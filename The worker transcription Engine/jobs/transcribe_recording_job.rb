# app/jobs/transcribe_recording_job.rb
class TranscribeRecordingJob < ApplicationJob
  include TranscriptionSorting
  queue_as :transcription_heavy # Ensure this has 'threads: 1' in your config!

  def perform(job_receipt_id)
    
    @recording_proxy = RecordingProxy.new
    @log_proxy = TranscriptionLogProxy.new
   # @resource_proxy = ResourceProxy.new
    @blob_proxy = BlobProxy.new
    begin
      job_receipt= JobReceipt.find(job_receipt_id)
      recording_id = job_receipt.recording_id
      
    #  temp_dir = Rails.root.join("tmp", "transcription_#{recording_id}")
      puts "DEBUG: TranscribeRecordingJob Starting, recording: #{recording_id}, job_receipt: #{job_receipt_id}"
      # logsand db calls at start of job
      
     db_and_logging_at_start( job_receipt)
     sleep 5
      # 1. Loop through chunks in order
     transcribe_chunks(job_receipt)
      
      # 4. FINAL ASSEMBLY AND  Save to S3 and Update DB
     
      transcripts = assemble_dual_transcripts(job_receipt)
      
      bank_in_active_storage(recording_id, job_receipt, transcripts)
      
      
     
      #      # 5. CLEANUP (The most important part for your VPS SSD!)
            finalize_recording_data( job_receipt)
      #          recording.log_status("finished finalize_recording_data.")
      #          Turbo::StreamsChannel.broadcast_remove_to(
      #         "transcription_monitor_channel",
      #         target: "transcription_monitor_job_recording_#{recording.id}"
      #      )
      # => for development purposes set recording transcription_status on the server to :completed.
      # since no raw_transcription attached this will fail validation the server will notify the worker
      # this allows the rails  job to complete but the data bases will be udated as failed
      success = @recording_proxy.update(job_receipt.recording_id, {transcription_status: :completed})
       
      unless success
        raise "Librarian Rejected Status Update: Likely validation failed (Check if transcript is attached?)"
      end
      
    rescue StandardError => e
     
      
      puts "\n" + "="*40
      puts "DEBUGGER HIT"
      puts "Error Class:   #{e.class}"
      puts "Error Message: #{e.message.inspect}" # <--- This tells you if it's nil
      puts "Error Source:  #{e.backtrace.first}"   # <--- This tells you the EXACT line
      puts "="*40 + "\n"
      job_receipt= JobReceipt.find(job_receipt_id)
      recording_id = job_receipt.recording_id
      
    
     
     
      job_receipt = JobReceipt.find(job_receipt_id)
      if job_receipt
         puts "failure job_receipt #{job_receipt.id}  #{job_receipt.recording_id}"
        # Attempt to mark the DB as failed
        msg = e.message || "Unknown Error"
        finalize_failed_transcription(job_receipt:job_receipt, error_message: msg.to_s)
      else
        # If DB is totally dead, we log to the system file so you can see it later
        Rails.logger.fatal "CRITICAL: recording #{job_receipt.recording_id} job_receipt #{job_receipt_id} failed and DB record is missing! Error: #{e.message}"
      end
      
    end
  end

  private
  
  def save_full_text_to_tmp(filename, full_text)
    # Path: /your_app/tmp/filename.txt
    filename = safe_file_name(filename)
    file_path = Rails.root.join('tmp', "#{filename}.txt")

    File.open(file_path, 'w') do |f|
      f.write(full_text)
    end
    puts "Test file saved to: #{file_path}"
  end
  
  def finalize_recording_data( job_receipt)
    #recording.log_status("lets finalize_recording_data.")
    # 1. CALCULATE TIME
    # job.started_at was set in 'db_and_logging_at_start'
    start_time = job_receipt.started_at || Time.current 
    end_time = Time.current
  
    # Ensure we have at least 1 second to avoid division by zero
    processing_seconds = [ (end_time - start_time).to_i, 1 ].max
  
    # Calculate audio length from chunks BEFORE we delete them
    file_length = job_receipt.wav_chunks.sum(:duration)
  
    # 2. SPEED CALCULATION
    # Use .to_f to ensure high-precision division
    # e.g., 300s audio / 30s processing = 10.0x
    speed = (file_length.to_f / processing_seconds).round(1)

    # 3. ATOMIC UPDATE
    job_receipt.transaction do
      job_receipt.update!(
        status: :completed,
        ended_at: end_time, 
        duration_seconds: processing_seconds, # Changed from processing_time
        speed: speed
      )
    
      # Shred the "Worksheets" (Chunks)
      job_receipt.wav_chunks.delete_all
     
      # Target path matches your defined: Rails.root.join("tmp", "transcription_#{recording_id}")
      remove_directory_from_tmp("recording_#{job_receipt.recording_id}")
    
    end
  
  #  job_receipt.log_status("Master: Finished! processing_seconds #{processing_seconds} Processed #{file_length}s of audio at #{speed}x speed.")
  end
  
  def bank_in_active_storage(recording_id, job_receipt, transcripts)
    # Force symbols so it doesn't matter if the hash came in with string keys
    data = transcripts.with_indifferent_access 
    # 1. Bank the TXT
    txt_body = data[:text] || ""
    txt_ticket = @blob_proxy.create({
      filename: "#{job_receipt.recording_title}.txt",
      key: "#{job_receipt.archive_folder}_txt/#{job_receipt.recording_title}.txt",
      byte_size: txt_body.bytesize,
      checksum: Digest::MD5.base64digest(txt_body),
      content_type: "text/plain"
    })
    CloudProxy.upload(txt_ticket, txt_body)

    # 2. Bank the VTT
    vtt_body = data[:vtt] || ""
    vtt_ticket = @blob_proxy.create({
      filename: "#{job_receipt.recording_title}.vtt",
      key: "#{job_receipt.archive_folder}_vtt/#{job_receipt.recording_title}.txt",
      byte_size: vtt_body.bytesize,
      checksum: Digest::MD5.base64digest(vtt_body),
      content_type: "text/vtt"
    })
    CloudProxy.upload(vtt_ticket, vtt_body)

    # 3. Update Recording 
    # Using .fetch ensures we crash with a clear message if 'signed_id' is missing
    @recording_proxy.update(recording_id, {
      transcription_status: "completed", 
      raw_transcript: txt_ticket.fetch('signed_id'),
      caption_file: vtt_ticket.fetch('signed_id') 
    })
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
  
  def assemble_transcript(job_receipt)
    @log_proxy.send_log(job_receipt.recording_id, "😀 Assemble transcript")
    final_transcript = []
    grouped_chunks = job_receipt.wav_chunks.completed.group_by(&:original_filename)
    sort_by_track_number(grouped_chunks.keys).each do |filename|
      final_transcript << "\n** Source File: #{filename} **\n"
    
      grouped_chunks[filename].sort_by(&:start_time).each do |chunk|
        txt_path = chunk.file_path.gsub(".wav", ".txt")
        
        # 1. Smart Timestamp Logic
        # If start_time is 3600 seconds or more, include the hour
        
        timestamp = "** segment start time ** #{formatted_start_time(chunk)} \n"
      
        raw_text = File.exist?(txt_path) ? File.read(txt_path).strip : ""
        content = raw_text.present? ? raw_text : "[ #{timestamp} MISSING OR SILENT SEGMENT]"
        final_transcript << "[#{timestamp}] #{content}"
      end
    end
    final_transcript.join("\n\n")
  end
  
  def assemble_dual_transcripts(job_receipt)
    final_txt = []
    final_vtt = ["WEBVTT\n\n"]
    last_marker_time = -300 

    grouped_chunks = job_receipt.wav_chunks.completed.group_by(&:original_filename)
    sort_by_track_number(grouped_chunks.keys).each do |filename|
      grouped_chunks[filename].sort_by(&:start_time).each do |chunk|
      
        vtt_path = "#{chunk.file_path}.vtt"

        if File.exist?(vtt_path)
          File.foreach(vtt_path) do |line|
            if (match = line.match(/(\d{2}):(\d{2}):(\d{2})\.\d{3}/))
              h, m, s = match.captures.map(&:to_i)
              current_total_seconds = (h * 3600) + (m * 60) + s + chunk.start_time
            
              if current_total_seconds >= (last_marker_time + 300)
                last_marker_time = current_total_seconds
              
                m_display = (current_total_seconds / 60).to_i
                s_display = (current_total_seconds % 60).to_i
              
                # Format as [M:SS] - e.g., [5:02] or [30:45]
                # %02d ensures the seconds always have two digits
                timestamp_string = "[#{m_display}:%02d]" % s_display
              
                final_txt << "[[MARKER]]#{timestamp_string}\n"
              end
            elsif line.strip.present? && !line.include?("WEBVTT") && !line.match(/-->/) && !line.match(/^\d+$/)
              final_txt << line.strip
            end
          end
        end

        if File.exist?(vtt_path)
          raw_vtt = File.read(vtt_path)
          final_vtt << offset_vtt_timestamps(raw_vtt, chunk.start_time)
        end
      end
    end

    full_prose = final_txt.join(" ")
                          .gsub(/\s*\[\[MARKER\]\]\s*/, "\n\n")
                          .gsub(/\n +/, "\n")
                          .strip

    { 
      text: full_prose, 
      vtt: final_vtt.join("\n") 
    }
  end
  
  
  def clean_vtt_to_text(raw_content)
    raw_content
      # 1. Remove timestamps with or without brackets: [00:00:00.000 --> 00:00:00.000]
      .gsub(/\[?\d{2}:\d{2}:\d{2}\.\d{3}.*-->.*\d{2}:\d{2}:\d{2}\.\d{3}\]?/, "")
      # 2. Remove the WEBVTT header
      .gsub("WEBVTT", "")
      # 3. Collapse multiple newlines/spaces into a single space for paragraph flow
      .gsub(/\s+/, " ")
      .strip
  end
  
  # Helper to shift "00:01:00" to "00:31:00" for Chunk 2
  def offset_vtt_timestamps(vtt_content, offset_seconds)
    vtt_content.gsub(/(\d{2}:\d{2}:\d{2}\.\d{3})/) do |timestamp|
      t = Time.parse("2000-01-01 #{timestamp}") + offset_seconds
      t.strftime("%H:%M:%S.%L")
    end.gsub("WEBVTT", "").strip
  end
  
  def run_whisper(path, prompt, config)
    raise "Whisper Model not found at: #{config[:model_path]}" unless File.exist?(config[:model_path])

    #  arguements for no time stamps
    #  args = [
    #    config[:bin_path], 
    #    "--model", config[:model_path],
    #    "--file", path, 
    #    "--language", "en", 
    #    "--no-timestamps",
    #    "--threads", "6",  #no_crash_website_thread_count.to_s, # Keep your existing logic
    #    "--prompt", prompt,
    #    "--max-context", "448",
    #    "--split-on-word"
    #  ]
    
    args = [
        config[:bin_path], 
        "--model", config[:model_path],
        "--file", path, 
        "--language", "en", 
        "--threads", "6",
        "--prompt", prompt,
        "--max-context", "448",
        "--split-on-word",
        "--output-vtt" 
      ]

    stdout, stderr, status = Open3.capture3(*args)
    status.success? ? stdout.strip : raise("Whisper Exit #{status.exitstatus}: #{stderr}")
  end
  
  def transcribe_chunks(job_receipt)
    config = Rails.application.credentials.dig(Rails.env.to_sym, :whisper)
     @log_proxy.send_log(job_receipt.recording_id, "Transcribing chunks...")
    job_receipt.wav_chunks.order(:id).each do |chunk|
      @log_proxy.send_log(job_receipt.recording_id, "Transcribing chunk at #{formatted_start_time(chunk)}...")
   
      # 2. CALL WHISPER (Replace with your specific Whisper command/service)
      # text = "Sample text for chunk #{chunk.id}" # Placeholder
      prompt = job_receipt&.recording_title.tr('_', ' ') || " " 
      transcript_text = run_whisper(chunk.file_path, prompt,config).to_s
      
      txt_path = chunk.file_path.gsub(".wav", ".txt")
      File.write(txt_path, transcript_text)
      chunk.completed!
    end
  end

  def finalize_failed_transcription(job_receipt:,  error_message:)
    # puts "puts 3 #{recording}"
     sleep 1
    
    job_receipt.transaction do
    #  job_receipt.wav_chunks.delete_all
      job_receipt.update(status: :failed, error_message: error_message)
     # recording.update(transcription_status: :failed)
     # if job_receipt
     #   job_receipt.update!(status: :failed, error_message: error_message)
     # end
     
    end
    begin
      attributes = { transcription_status: :failed }
      puts "base attributes #{attributes}"
      puts "[M4] recording_#{job_receipt.recording_id}"
      # add job receipt attributes so the server can document the failed job
      attributes[:job_receipts_attributes] = [{
          status: :failed,
          error_message: error_message
        }]
        puts "full attributes #{attributes}"
      remove_directory_from_tmp("recording_#{job_receipt.recording_id}")
       @recording_proxy.update(job_receipt.recording_id, attributes)
      # Optional: Log the specific failure reason to the server's audit trail
      @log_proxy.send_log(job_receipt.recording_id, "❌ Prep Failed: #{error_message}")
    rescue => e
      puts "[M4] Failed to notify Librarian of job failure: #{e.message}"
    end
  end
  
  def no_crash_website_thread_count
    total_cores = Etc.nprocessors rescue 2
    # Leave 1 core free on small machines, 2 on medium, 4 on large
    reserved = if total_cores <= 4
                 1
               elsif total_cores <= 8
                 2
               else
                 4
               end
    [total_cores - reserved, 1].max # Ensure we use at least 1 thread
  end
  
  def formatted_start_time(chunk)
    format = chunk.start_time >= 3600 ? "%H:%M:%S" : "%M:%S"
    Time.at(chunk.start_time).utc.strftime(format)
  end
  
  
  def db_and_logging_at_start( job_receipt)
    @log_proxy.send_log(job_receipt.recording_id, "😀")
    @log_proxy.send_log(job_receipt.recording_id, "🚀 Starting Transcription Job for Recording ##{job_receipt.recording_id}
    Starting Whisper engine for #{job_receipt.wav_chunks.count} chunks.")
    
    if job_receipt.update!(started_at: Time.current, status: :processing)
      @recording_proxy.update(job_receipt.recording_id, {transcription_status: :processing})
    end
    
  end
  
  def safe_file_name(filename)
    filename.gsub('&', 'and').parameterize
  end
  
  def remove_directory_from_tmp(directory)
    temp_dir = Rails.root.join("tmp", directory)
  
    if Dir.exist?(temp_dir)
      FileUtils.rm_rf(temp_dir)
    end
  end
  
end