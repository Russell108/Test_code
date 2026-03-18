#To summarise our work
#input files can be of the following types
#  1 Audio file
#  2 video file
#  3 zip file containing one or more Audio files  with natural human numbering
#  4 zip file containing one or more Vidoe files  with natural human numbering
#  
# 
#  Database logic
#  each file belongs to a resource
#  a recording has many resources

# a recurring job prioritises the next  recording and adds it to the transcribe queu
# the TranscriptionService process the job
# 
#. # The work flow in  TranscriptionService 
#. 1 the most appropriate resource is found for transcription
#. 2 the file is downloaded to a temp file using Active storage
#. 3 prepare_audio_sourcemethod called
#.   a. if not a zip file return the file
#.   b. if a zip file unzip the files check for non mp3 files s
#.   c.  add files to directory
#.   d. return an array of file paths sorted in natural order
#. 4 the reurned array of files is passed to process_chunks method
#.   Each files in the array is 
#.     a. extracted into 300 second chunks vai ffmpeg into wav files
#.     b. transcribed by whisper and added to transcript_segments array
#.     c. the transcribed segments are joined and returned
#. 5. the transcription is saved
#. the recording transcription_status is updated

# the human Logic
# 1 call: Start the job and prepare the source.
# 2 prepare_audio_source: Unzip and sort the tracks (The "Natural Sort").
# 3 process_audio_source: The high-level loop through your files.
# 4 process_single_file: Managing the specific yoga track and its internal continuity.
#  process_chunk: The "workhorse" that handles FFmpeg and Whisper.

#/service/transcription_service.rb

#class TranscriptionServiceWithWhispercpp
#require 'openai'
require 'open3'
require 'zip'
class TranscriptionService
  include ActionView::Helpers::TextHelper
  CHUNK_SIZE = 300 # seconds
  
  DEFAULT_PROMPT = "Dru Yoga, Buttocks, Vinyasa, Pranayama, Asana, Namaste, Savasana, Tadasana, Ujjayi breath, Chakra, Surya Namaskar, Adho Mukha Svanasana"

  def initialize(recording)
    @recording = recording
    @config = Rails.application.credentials.dig(Rails.env.to_sym, :whisper)
    raise "Whisper credentials missing" if @config.nil?
    @threads =no_crash_website_thread_count
    log("no_crash_website_thread_count  #{@threads}")
  end


  def call
    # 1. STOP if a transcript already exists (prevent overwriting/re-running)
    return if already_transcribed?
    
    start_historical_job_data
    
    Rails.logger.debug "\n\n\recording_details #{recording_details}\n\n"
    
    resource = @recording.best_transcribable_resource.presence || raise("No valid transcribable resource found")


    resource = @recording.best_transcribable_resource
    
    raise "No valid transcribable resource found" unless resource
  
    # 1. Create your working directory first
    Dir.mktmpdir("transcription_#{@recording.id}_", Rails.root.join("storage")) do |working_dir|
      # 2. Sanitize the filename: replace any non-alphanumeric chars with an underscore
      clean_filename = resource.file.filename.to_s.gsub(/[^\w\.\-]/, '_')
      
      # 3. Define the path for the initial download
      # We use the original filename to ensure 'unzip_to_folder' knows if it's a .zip
      initial_download_path = File.join(working_dir, clean_filename)
  

      # 4. MANUAL STREAMED DOWNLOAD (The Speed Fix)
      File.open(initial_download_path, "wb") do |f|
        puts "\n\nStreaming file from cloud to: #{initial_download_path}"
        log("Streaming file from cloud to: #{initial_download_path}")
        resource.file.download { |chunk| f.write(chunk) }
      end
      
      ## Replace your block with this: just for development to replace 4 above
   #   puts "\n\nIO.copy_stream to: #{initial_download_path}"
   #   local_file_name = "S10_Please_Put_An_End_to_Conflict_In_Your_Life.zip"
   #   IO.copy_stream(Rails.root.join("storage", local_file_name), initial_download_path)

  
     
  
      # 4. Continue with your existing logic
     
      sorted_files, total_duration  = prepare_audio_source(initial_download_path, working_dir, resource.file.filename.to_s)
    
     transcripion_text = process_audio_source(sorted_files, working_dir)
      #transcripion_text = "my fll text"
      
   #   save_transcript(transcripion_text)
      attach_as_active_storge(transcripion_text, @recording)
       log("transcript saved")
     
      # --- PHASE 2 & 3: Finalize and Clear UI ---
       @recording.update!(
         transcription_status: 'completed',
         transcription_attempts: 0,
         file_length: total_duration,
         transcribed_at: Time.current
       )
      finalize_job("completed")
      
    end 
  rescue => e
    @recording.update!(transcription_status: 'failed', transcribed_at: Time.current, error_message: e.message)
    
    # Ensure cleanup happens even on failure
    finalize_job("failed") if @job_record
    Rails.logger.error "Transcription failed [Recording #{@recording.id}]: #{e.message}"
    raise e 
  end
  
  private
  
  def already_transcribed?
    return false unless @recording.raw_transcript.attached?

    message = "Transcription skipped: Recording #{@recording.id} already has a transcript."
    puts message
    Rails.logger.warn message
  
    @recording.update!(transcription_status: 'completed') unless @recording.completed?
    true
  end
  
  def start_historical_job_data
    # Create the audit log
    @job_record = TranscriptionJob.create!(
      recording: @recording, 
      started_at: Time.current, 
      status: 'running'
    )

    # Set the heartbeat/status for the Watchdog
    @recording.update!(transcription_status: 'processing')
  
    # Broadcast the Log Box to Admin Dashboard
    Turbo::StreamsChannel.broadcast_prepend_to(
      "transcription_monitor_channel",
      target: "transcription_monitor_jobs",
      partial: "transcription/recordings/transcription_monitor_job",
      locals: { recording: @recording }
    )
  end

  def prepare_audio_source(input_path, full_destination_path, filename)
    # 1. Branch: Is it a single file or a Zip?
    source_files = if filename.downcase.end_with?('.zip')
                     log("Extracting tracks from Zip archive...")
                     unzip_to_folder(input_path, full_destination_path)
                   else
                     [input_path.to_s]
                   end

    # 2. Sort the internal tracks (Human Logic)
    sorted_files = sort_by_track_number(source_files)
  
    # 3. ANALYTICS: Calculate internal complexity
    track_count = sorted_files.size
    total_seconds = sorted_files.sum { |path| get_duration(path) }.round
    log("#{track_count} tracks found, total audio duration detected: #{format("%02d:%02d", *( total_seconds.divmod(60) ) )} seconds.")
    total_seconds = sum_and_log_times(sorted_files)
    
    
    # Update the Recording 'Truth'
    @recording.update!(file_length: total_seconds)
  
    # 4. THE LOG: Single clear line for the Admin
    
  
    [sorted_files, total_seconds]
  end

  def unzip_to_folder(zip_file_path, full_destination_path)
    
    extracted_paths = [] # Track the files here
  
    Zip::File.open(zip_file_path) do |zip_entries|
      zip_entries.each do |entry|
        next if entry.directory? || File.basename(entry.name).start_with?('.') || entry.name.include?('__MACOSX') 
        
        clean_filename = File.basename(entry.name).gsub(/[^\w\.\-]/, '_') 
        
        if clean_filename.match?(/\.(mp3|wav|aiff?|m4a|mp4|mov)$/i)
          extract_path = File.join(full_destination_path, clean_filename)
          
          File.open(extract_path, "wb") { |f| f.write(entry.get_input_stream.read) }
  
          if File.exist?(extract_path)
            extracted_paths << extract_path # Store the path
            Rails.logger.debug "SUCCESS: Extracted to #{extract_path}"
          else
            # If the file didn't actually save to the disk
            Rails.logger.error "FAILED: Could not find extracted file at #{extract_path}"
          end
        end
      end
    end
   return extracted_paths # Return the list of files to the main 'call' method
  end

  def sort_by_track_number(extracted_files)
    extracted_files.sort_by do |path|
      file_name = File.basename(path)

      # Regex: Look for digits (\d+) followed by a dot and the extension at the end ($)
      # This ignores IDs at the start and dates in the middle.
      match = file_name.match(/(\d+)\.[^.]+$/)
    
      # If no number is found at the end, default to 0 to prevent crashes
      track_number = match ? match[1].to_i : 0
    
      # Print to Rails console so you can verify the sequence during processing
     # puts "📂 Transcription Queue: Track #{track_number.to_s.rjust(2, '0')} -> #{file_name}"
    
      # Sort by the integer track_number
      track_number
    end
  end

  def determine_duration(file_path)
    cmd = "ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 #{file_path}"
    duration = `#{cmd}`.to_f
    raise "Could not determine duration" if duration <= 0
    duration
  end

  def process_audio_source(source_input, working_dir)
    puts "process_audio_source"
    log("process_audio_source")
    
    # 1. Normalize input to always be an array
    source_files = Array(source_input)
    puts "number of source files #{source_files.length}"
    log("number of source files #{source_files.length}")
    # 2. Map over each file to get its transcript
    source_files.map do |file_path|
      process_single_file(file_path, working_dir)
    end.join("\n\n")
  end


  def process_single_file(file_path, working_dir)
    file_label = File.basename(file_path)
    
  
    transcript_segments = ["** Track: #{file_label} **\n"]
    current_prompt = DEFAULT_PROMPT
    current_start = 0
  
    total_duration = determine_duration(file_path)
     puts "🚀 Processing: #{file_label} duration: #{format("%02d:%02d", *( total_duration.divmod(60)))} "
     log("🚀 Processing: #{file_label} duration: #{format("%02d:%02d", *( total_duration.divmod(60)))} ")
    # Loop through the specific file in chunks
    while current_start < total_duration
      text, chunk_path = process_chunk(file_path, current_start, working_dir, current_prompt)
      
   # text = current_start.to_s
      log("current_start  #{current_start} ")
    
      if text.present?
         transcript_segments << (  (format("%02d:%02d", *( current_start.divmod(60) ) ) ).to_s )
      #  puts "text: #{text}"
        transcript_segments << text
        
        # Update prompt for the NEXT chunk in the SAME file
     #   current_prompt = "#{text.last(200)} #{DEFAULT_PROMPT}"
      else
        puts "text empty"
      end
   
      current_start += CHUNK_SIZE
    end
  #  Rails.logger.debug "\n\ntranscript_segments #{transcript_segments}\n\n"
    transcript_segments.join("\n")
  end

  def process_chunk(file_path, start_time, working_dir, prompt)
    # Create a unique name for this specific chunk
    chunk_name = "#{File.basename(file_path, '.*')}_at_#{start_time.to_i}.wav"
    chunk_path = File.join(working_dir, chunk_name)
    log("get segment and extract #{Time.now}")
    extract_segment(file_path, chunk_path, start_time, CHUNK_SIZE)
       log("run_whisper #{Time.now}")
    text = run_whisper(chunk_path, prompt)
 #   [chunk_name, chunk_path]# need to remove this and uncomment other 2 lines aboew and below
   log("whisper run complete #{Time.now}")
    [text, chunk_path]
  end
  
  # Update the helper method to accept duration
  def extract_segment(input, output, start, duration)
    args = [
      "nice", "-n", "15", "ffmpeg", "-y",
      "-i", input,
      "-ss", start.to_s, 
      "-t", duration.to_s, # exactly 300 
      "-ar", "16000", 
      "-ac", "1", 
      "-af", "arnndn=model=bd.rnnn, highpass=f=200, lowpass=f=3000, silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-40dB",
      "-c:a", "pcm_s16le",
       output
    ]
    _o, e, s = Open3.capture3(*args)
    Rails.logger.error "FFmpeg Error: #{e}" unless s.success?
  end
   
  def run_whisper(path, prompt)
    # 1. Start with your existing base arguments
   
    unless File.exist?(@config[:model_path])
       raise "Whisper Model not found at: #{@config[:model_path]}"
     end
    args = [
      @config[:bin_path], 
      "--model", @config[:model_path],
      "--file", path, 
      "--language", "en", 
      "--no-timestamps",
      "--threads", "#{@threads.to_s}", # "4",
      "--prompt", prompt,
      "--max-context", "64"               
    ]

    # 2. Add the split-on-word flag
    # This helps Whisper not 'hallucinate' or skip words at the end of audio segments
    args << "--split-on-word"

    # 3. Execute the command
    stdout, stderr, status = Open3.capture3(*args)
  
    if status.success?
       stdout.strip
     else
       # Capture stderr to see exactly why whisper.cpp failed
       error_msg = "Whisper CLI Exit #{status.exitstatus}: #{stderr}"
       Rails.logger.error error_msg
       raise error_msg # Raise an exception so your background job retries or fails visibly
     end
  end
  
  def save_transcript(text)
   
    save_dir = Rails.root.join("storage", "transcripts")
    FileUtils.mkdir_p(save_dir)
    
    safe_title = @recording.title.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')
    filename = "transcript_#{@recording.happening_id}_S#{@recording.number}_#{safe_title}.txt"
    text_and_metadata = "\n** filename ** #{filename}\n\n"
    text_and_metadata << recording_details + "\n" + text
    File.write(save_dir.join(filename), text)
  end
  
  def recording_details
    recording_details = "#### Metadata start ####\n\n"
    (recording_details << "** Course tilte **\n#{@recording.happening.happenable.title}\n")if @recording.happening.type =="Meet" 
    recording_details << "** Happening title **\n#{@recording.happening.title}\n"
    recording_details << "** Recording title **\nS#{@recording.number} #{@recording.title}\n"
    recording_details << "** start time **\n#{@recording.start_datetime.to_fs(:long)}\n"
    recording_details << "** Speakers **\n#{@recording.speakers.joins(:contributions).group('speakers.id').order('BOOL_OR(contributions.main) DESC','speakers.created_at ASC').pluck(:stage_name).join(", ")}\n"
    recording_details << "** Write-up **\n#{@recording.writeup.to_plain_text.strip }\n"
    recording_details << "\n#### Metadata end ####\n\n"

#    #### Transcript start ####
#    
#    ** Time minutes seconds of the chunks ** # does not need a label
#    ** Track x
#    transcript
    
    
     #### Transcript end ####

    
  end
  
  def attach_as_active_storge(full_text, recording)
    filename ="#{recording.happening_id} S#{recording.number} #{recording.title}".gsub(/[^\w\.\-]/, '_')
    custom_key = "#{filename}.txt"
    text_and_metadata = "\n** filename ** #{custom_key}\n\n"
    text_and_metadata << recording_details + "\n" 
    text_and_metadata << "\n #### Transcript start ####\n\n"
    text_and_metadata <<  full_text
    text_and_metadata << "\n\n#### Transcript end ####\n\n"
      # 2. Create the blob with the specific key
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(text_and_metadata),
        filename: "#{custom_key}",
        content_type: "text/plain",
        key: custom_key, # This forces the disk/S3 path
        # Force use of the override service
        service_name: :raw_transcripts 
      )

      # 3. Attach this specific blob to your recording
      recording.raw_transcript.attach(blob)
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
  
  def log(message)
    @recording.transcription_logs.create!(message: message)
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
  
  def get_duration(file_path)
    # -v error: only show errors
    # -show_entries format=duration: just get the time
    # -of csv=p=0: return just the number, no labels
    command = "ffprobe -v error -show_entries format=duration -of csv=p=0 '#{file_path}'"
    duration, stderr, status = Open3.capture3(command)
  
    if status.success?
      duration.to_f
    else
      Rails.logger.error "FFprobe failed for #{file_path}: #{stderr}"
      0.0
    end
  end
  
  def sum_and_log_times(sorted_files)
    total_seconds=0
    sorted_files.each do |path|
       file_label = File.basename(path)
      duration = get_duration(path).round
      total_seconds += duration
    
      # Print each track's time to the log box in real-time
      log(" #{File.basename(path)} #{format("%02d:%02d", *( duration.divmod(60)))}")
    end
    total_seconds
  end
  
end
