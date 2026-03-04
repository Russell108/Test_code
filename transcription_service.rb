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
  end

  def call
    @recording.update!(transcription_status: 'processing')
   
    # Use your model's logic to find the best file (Zip, Movie, or MP3)
    resource = @recording.best_transcribable_resource
    raise "No valid transcribable resource found" unless resource
     puts "\n\nDownloading file\n"
    # ActiveStorage 'open' creates a local temp file for Whisper/FFmpeg to read
    resource.file.open do |temp_file|
      puts "\n\nFile downloaded to: #{temp_file.path}\n"
       puts "Exists? #{File.exist?(temp_file.path)}\n\n" # Should be true
 
      Dir.mktmpdir("transcription_#{@recording.id}_", Rails.root.join("storage")) do |working_dir|
        puts "working_dir: #{working_dir}"
        # Your function is called here, using the temp path
        puts "prepare_audio_source"
        source_files = prepare_audio_source(temp_file.path, working_dir,resource.file.filename.to_s )
        puts "process_audio_source"
        full_text = process_audio_source(source_files, working_dir)
         save_transcript(full_text)
      end # Everything in working_dir is automatically nuked here!
 
        @recording.update!(
          transcription_status: 'completed',
          transcribed_at: Time.current#,
        )
         Rails.logger.debug "\n\njob complete\n\n"
         puts "transcription complete"
     #  end
    end
  rescue => e
    @recording.update!(transcription_status: 'failed',transcribed_at: Time.current, error_message: e.message)
    Rails.logger.error "Transcription failed [Recording #{@recording.id}]: #{e.message}"
    raise e 
  end

  private

  def prepare_audio_source(input_path, full_destination_path, filename)
    # Ensure we always return an array for consistency
    return [input_path.to_s] unless filename.downcase.end_with?('.zip')
    extracted_paths = unzip_to_folder(input_path, full_destination_path)
    extracted_paths = sort_by_track_number(extracted_paths)
    extracted_paths.each { |file_path| puts "#{file_path}\n" }
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
    # 1. Normalize input to always be an array
    source_files = Array(source_input)
  
    # 2. Map over each file to get its transcript
    source_files.map do |file_path|
      process_single_file(file_path, working_dir)
    end.join("\n\n")
  end


  def process_single_file(file_path, working_dir)
    file_label = File.basename(file_path)
    
  
    transcript_segments = ["--- Track: #{file_label} ---"]
    current_prompt = DEFAULT_PROMPT
    current_start = 0.0
    total_duration = determine_duration(file_path)
     puts "🚀 Processing: #{file_label} duration: #{format("%02d:%02d", *( total_duration.divmod(60)))} "
    # Loop through the specific file in chunks
    while current_start < total_duration
      text, chunk_path = process_chunk(file_path, current_start, working_dir, current_prompt)
    
      if text.present?
      #  puts "text: #{text}"
        transcript_segments << text
        # Update prompt for the NEXT chunk in the SAME file
        current_prompt = "#{text.last(200)} #{DEFAULT_PROMPT}"
      else
        puts "text empty"
      end
    
      current_start += CHUNK_SIZE
    end

    transcript_segments << "\n"
    transcript_segments.join("\n")
  end

  def process_chunk(file_path, start_time, working_dir, prompt)
    # Create a unique name for this specific chunk
    chunk_name = "#{File.basename(file_path, '.*')}_at_#{start_time.to_i}.wav"
    chunk_path = File.join(working_dir, chunk_name)

    extract_segment(file_path, chunk_path, start_time, CHUNK_SIZE)
    text = run_whisper(chunk_path, prompt)
 #   [chunk_name, chunk_path]# need to remove this and uncomment other 2 lines aboew and below
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
    args = [
      @config[:bin_path], 
      "--model", @config[:model_path],
      "--file", path, 
      "--language", "en", 
      "--no-timestamps",
      "--threads", "4",
      "--prompt", prompt,
      "--max-context", "64"               
    ]

    # 2. Add the split-on-word flag
    # This helps Whisper not 'hallucinate' or skip words at the end of audio segments
    args << "--split-on-word"

    # 3. Execute the command
    stdout, stderr, status = Open3.capture3(*args)
  
    if status.success?
      return stdout.strip
    else
      Rails.logger.error "Whisper Error: #{stderr}"
      ""
    end
  end
  
  def save_transcript(text)
    text_and_metadata =recording_details + "\n" + text
    save_dir = Rails.root.join("storage", "transcripts")
    FileUtils.mkdir_p(save_dir)
    
    safe_title = @recording.title.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')
    filename = "transcript_#{@recording.happening_id}_S#{@recording.number}_#{safe_title}.txt"
    
    File.write(save_dir.join(filename), text_and_metadata)
  end
  
  def recording_details
    recording_details =""
    
    recording_details <<("Course: #{@recording.happening.happenable.title}\n")if(@recording.happening.type =="Meet") 
    recording_details <<("#{@recording.happening.type}: #{@recording.happening.title}\n")
    recording_details <<"Venue: #{@recording.happening&.venue&.name} \n" if @recording.happening.venue
    recording_details <<"#{@recording.title}\n"
    recording_details <<"#{@recording.start_datetime.to_fs(:long)}"
    recording_details <<"Speakers:#{@recording.speakers.joins(:contributions).group('speakers.id').order('BOOL_OR(contributions.main) DESC','speakers.created_at ASC').pluck(:stage_name)}\n"
    recording_details <<"Content: #{formatted_writeup}\n"
    recording_details
  end
  
  def formatted_writeup
   html =  @recording.writeup.to_s
   strip_tags(html.gsub(/<br\s*\/?>/i, "\n")).strip
  end
end
