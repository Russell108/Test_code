# app/jobs/transcription_prep_job.rb
require 'zip'

class TranscriptionPrepJob < ApplicationJob
  include TranscriptionSorting
  queue_as :transcription_prep

  def perform(job_id)
    puts "DEBUG: RUNNING NEW VERSION OF TranscriptionPrepJob 16-38"
    @job = TranscriptionJob.find(job_id)
    
    start_historical_job_data(@job) #initialise logging window and first log
    
    # 1. Setup a clean temp directory
    temp_dir = Rails.root.join("tmp", "transcription_#{@job.id}")
    FileUtils.mkdir_p(temp_dir)

    # 2. Download Source
    
    source_path = download_source_file(@job, temp_dir)

    # 3. Handle ZIP vs Single File
    files_to_process = []
    if is_zip?(source_path)
      # Pass the path and the temp_dir we created at the start
      extracted_files = unzip_to_folder(source_path, temp_dir)
      files_to_process = sort_by_track_number(extracted_files)
      (extracted_files)
    else
      files_to_process << source_path
    end

    # 4. Slice into 300s chunks in the sorted order
    files_to_process.each do |file| 
      create_chunks_from_file(file, temp_dir)
    end
    
    
     @job.recording.prepared!
    
  end

  private
  
  def start_historical_job_data(job)
    puts "job #{job.inspect}"
    # Create the audit log
    job.recording.log_status("System: Prep started for Job ##{job.id}. Setting up workspace...")
    # Set the heartbeat/status for the Watchdog
    job.touch
    # Broadcast the Log Box to Admin Dashboard
    Turbo::StreamsChannel.broadcast_prepend_to(
      "transcription_monitor_channel",
      target: "transcription_monitor_jobs",
      partial: "transcription/recordings/transcription_monitor_job",
      locals: { recording: job.recording }
    )
  end
  
  def unzip_to_folder(zip_file_path, temp_dir)
    extracted_paths = []
     job.recording.log_status("prepare files #{Time.now.utc.strftime("%M:%S")}")
    Zip::File.open(zip_file_path) do |zip_entries|
      zip_entries.each do |entry|
        # 1. Skip junk, mac metadata, and directories
        next if entry.directory? || File.basename(entry.name).start_with?('.') || entry.name.include?('__MACOSX') 
      
        # 2. Clean the name and ensure it's a media file
        clean_filename = File.basename(entry.name).gsub('&', 'and')
                .gsub(/[^\w\.\-\(\)\&]/, '_')#.gsub(/[^\w\.\-]/, '_') 
      
        if clean_filename.match?(/\.(mp3|wav|aiff?|m4a|mp4|mov)$/i)
          # 3. Join carefully to avoid doubling up the Rails.root
          extract_path = File.join(temp_dir, clean_filename)
        
          # 4. Write the file bits to the VPS SSD
          File.open(extract_path, "wb") { |f| f.write(entry.get_input_stream.read) }

          if File.exist?(extract_path)
            extracted_paths << extract_path
            Rails.logger.debug "SUCCESS: Extracted to #{extract_path}"
          else
            Rails.logger.error "FAILED: Could not find extracted file at #{extract_path}"
          end
        end
      end
    end
    extracted_paths
  end

  def download_source_file(job, temp_dir)
    resource = job.recording.best_transcribable_resource.presence
    raise "No valid transcribable resource found job id:#{job.id} recording id: #{job.recording.id}" unless resource
    Rails.logger.debug "\n\nclean_filename to follow #{resource.file.filename} \n\n"
    clean_filename = resource.file.filename.to_s.gsub('&', 'and')
                .gsub(/[^\w\.\-\(\)\&]/, '_')#.to_s.gsub(/[^\w\.\-]/, '_')
    #local_path = temp_dir.join(clean_filename)
    local_path = Pathname.new(temp_dir).join(clean_filename)
    Rails.logger.debug "\n\nlocal_path #{local_path}\n\n"
    job.recording.log_status("download started #{Time.now.utc.strftime("%M:%S")}")
    File.open(local_path, "wb") do |file|
      resource.file.download { |chunk| file.write(chunk) }
    end
    job.recording.log_status("download complete #{Time.now.utc.strftime("%M:%S")}")
    local_path.to_s
  end

  def create_chunks_from_file(file_path, temp_dir)
    current_time = 0
    # ffprobe is perfect here to get the total length
    duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{file_path}"`.to_f
    puts "file_path #{file_path}"
    # Ensure the prefix is unique to the specific track
    file_prefix = File.basename(file_path, '.*').gsub('&', 'and')
                .gsub(/[^\w\.\-\(\)\&]/, '_')#.gsub(/[^\w\-]/, '_')

    while current_time < duration
      # 1. Look for silence in a 10s window (5s before and after the 300s mark)
      # Seeking BEFORE -i is fast but resets the filter clock to 0
      search_start = current_time + 295
      cmd = "ffmpeg -ss #{search_start} -t 10 -i \"#{file_path}\" -af silencedetect=n=-25dB:d=0.4 -f null - 2>&1"
      output = `#{cmd}`
  
      # 2. Extract the relative timestamp
      silence_match = output.match(/silence_start: ([\d\.]+)/)
    
      # If silence is found at 3.5s into our 10s window, the real cut is at 295 + 3.5
      relative_cut_point = silence_match ? silence_match[1].to_f : 5.0
      chunk_len = 295 + relative_cut_point

      # 3. Safety Check: Ensure we don't go past the end of the file
      if (current_time + chunk_len) > duration || (duration - (current_time + chunk_len)) < 30
        chunk_len = duration - current_time
      end

      # 4. Unique Naming: Using the timestamp ensures no overwrites
      chunk_filename = "#{file_prefix}_at_#{current_time.to_i}.wav"
      dest_path = File.join(temp_dir, chunk_filename)

      # 5. Extract the actual chunk
      system("ffmpeg -ss #{current_time} -threads 2 -t #{chunk_len} -i \"#{file_path}\" -ar 16000 -ac 1 -c:a pcm_s16le \"#{dest_path}\"")

      # 6. Save to DB
      chunk =@job.transcription_chunks.create!(
        file_path: dest_path.to_s,
        original_filename: File.basename(file_path),
        start_time: current_time,
        duration: chunk_len,
        status: :pending
      )
      TranscribeChunkJob.perform_later(chunk.id)
      # 7. Advance the clock
      current_time += chunk_len
    
      # Break if we've reached the end to prevent infinite loops
      break if chunk_len <= 0
    end
  end

  def sort_by_track_number(extracted_files)
    extracted_files.sort_by do |path|
      file_name = File.basename(path)
      match = file_name.match(/(\d+)\.[^.]+$/)
      match ? match[1].to_i : 0
    end
  end


  def is_zip?(path)
    File.extname(path).downcase == '.zip'
  end

  def is_audio_or_video?(path)
    %w[.mp3 .wav .m4a .mp4 .mov .avi .mkv].include?(File.extname(path).downcase)
  end
end
