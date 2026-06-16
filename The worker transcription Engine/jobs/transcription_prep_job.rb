# app/jobs/transcription_prep_job.rb (On the M4)
require 'zip'

class TranscriptionPrepJob < ApplicationJob
  include TranscriptionSorting
  queue_as :transcription_prep # [cite: 39]

  def perform(job_receipt_id)
    # prep workspace
    # get meta data from server
    # download source file
    # if zip extract and sort if necessary
    # create chunks in preparation for transcription different job
    # combine files if necessary in preparation for conversion
    # convert and archive file if necessary
    # swap file on active storage if necessary update server
    # finalise job and create transcribe recording job #currently this should be commented out
    
    # current issues
    # we should check if resource has already upgraded with converted file and custom key if it has
    # there is no need to convert or archive, but we do need to chunk and prep for transcription
    # we should check local archive storage to see if it's still available
    #  job should not stop if files does not need converting
    #  server should register when resourse attached file has been upgraded
    
    # 
    
    ffmpeg_info = `ffmpeg -version | head -n 1`.strip
    ffmpeg_path = `which ffmpeg`.strip
    puts "DEBUG: TranscriptionPrepJob Starting. FFmpeg: #{ffmpeg_info} at #{ffmpeg_path}"
    puts "job_receipt_id #{job_receipt_id}"
    job_receipt = JobReceipt.find(job_receipt_id)
    recording_id =job_receipt.recording_id
    @temp_dir = Rails.root.join("tmp", "recording_#{recording_id}")
    @archive_storage = "/Users/russellroberts/archive_storage" # absolute path here   ##for_the_transcode_job 
    puts "DEBUG: Cleaning workspace for Recording ##{recording_id}"
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
    FileUtils.mkdir_p(@temp_dir)
    @recording_proxy = RecordingProxy.new
    @resource_proxy = ResourceProxy.new
    @log_proxy = TranscriptionLogProxy.new
    
    
    begin
      
      prep_workspace(job_receipt,recording_id)
      s3_metadata = request_metadata_from_server(job_receipt: job_receipt, recording_id: recording_id)
     
      s3_client, service_config = initialize_s3_client(s3_metadata)
      
            
      source_path = determine_source(s3_metadata, @temp_dir, recording_id,s3_client, service_config) 
      
      
   
      files_to_process = is_zip?(source_path) ? 
          sort_by_track_number(unzip_to_folder(@log_proxy, recording_id, source_path, @temp_dir)) : 
          [source_path]
      
      files_to_process.each{|file|  create_chunks_from_file(job_receipt, file, @temp_dir)}
     
      master_file =combine_files(files_to_process, recording_id)
      puts "master file #{master_file}"
       
   
      
      if s3_metadata['cloud_upgraded'] == true 
        @log_proxy.send_log(recording_id, "ℹ️ Resource already upgraded on Cloud Storage. Skipping archive step.")
      else
        # 🌟 ARCHIVE PIPELINE: Only runs if the asset hasn't been verified as upgraded
        archive_path = convert_file(file_path: master_file, recording_id: recording_id, s3_metadata: s3_metadata)
        
        if archive_path && File.exist?(archive_path)
          # Cloud Swap (Targets the specific Resource)
          swap_and_verify_cloud_storage(
            client: s3_client,
            service_config: service_config,
            local_path: archive_path,
            s3_metadata: s3_metadata,
            recording_id: recording_id
          )
        end
      end
            
      
        
      
  
      job_receipt.transaction do
        job_receipt.update!(status: :prepared, master_file: master_file)
        @log_proxy.send_log(recording_id, "🌈 Prep Job complete for Recording ##{recording_id}")
        
        @recording_proxy.update(recording_id, {transcription_status: :prepared})
      
        # TranscribeRecordingJob.perform_later(job_receipt_id)
          
        @log_proxy.send_log(recording_id, "Prep: Slicing complete. #{job_receipt.wav_chunks.count} chunks ready. Enqueued Muscle Job ")
      end
      
      # YOUR HARD STOP FOR TESTING
     # raise "🏁 TEST BREAKPOINT: Media chunked  successfully . Stopping here to inspect files."
     
   
     

    rescue => e
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
  
  def determine_source(s3_metadata, temp_dir, recording_id,s3_client, service_config)
    # If the Librarian says it's on the NAS, try the Fast Path first
    if s3_metadata['locally_archived']
      safe_file_name = s3_metadata['filename'].gsub(' ', '_')
      local_path = File.join(@archive_storage, s3_metadata['archive_folder'], safe_file_name)

      if File.exist?(local_path)
        @log_proxy.send_log(recording_id, "🚀 Using local source: #{s3_metadata['archive_folder']}")
        dest = File.join(temp_dir, safe_file_name)
        FileUtils.cp(local_path, dest)
        return dest
      end

      @log_proxy.send_log(recording_id, "⚠️ Archive flag is set, but file missing from NAS. Falling back...")
    end

    # Fallback: The Sliver/Linode Cloud download
    download_source_file(s3_metadata, temp_dir, recording_id,s3_client, service_config)
  end
  
  def initialize_s3_client(s3_metadata)
    service_name = s3_metadata['service_name']
    Rails.logger.debug "\n\ndownload_source_file\n\n"
    # 1. Manual Read: We go directly to the source because Rails.configuration can be nil
    storage_path = Rails.root.join("config", "storage.yml")
    puts "service_name #{service_name}"
    # ERB.new(...).result runs the Ruby code inside the YAML (pulling from credentials/ENV)
    raw_config = ERB.new(File.read(storage_path)).result
    all_configs = YAML.safe_load(raw_config, aliases: true)
  
    service_config = all_configs[service_name] || raise("Service #{service_name} not found in storage.yml")
    client = Aws::S3::Client.new(
      endpoint: service_config["endpoint"],
      access_key_id: service_config["access_key_id"],
      secret_access_key: service_config["secret_access_key"],
      region: service_config["region"],
      logger: Rails.logger, 
      http_wire_trace: false
    )
    [client, service_config]
  end
  
  def combine_files(files_to_join, recording_id)
    # 1. Type Safety: Force whatever comes in (String or Array) into an Array
    # This prevents the "undefined method 'one?' for String" error.
    files = Array(files_to_join)

    # 2. Early Exit: If there is only one file, return it immediately. 
    # No FFmpeg needed, no bits touched.
    return files.first if files.one?
  
    # 3. Error Handling: Just in case the list is empty
    if files.empty?
      raise "CombineFiles Error: No files were provided to join for Recording ##{recording_id}"
    end

    # 4. Preparation: Use the extension of the first file for the output
    ext = File.extname(files.first)
    combined_path = File.join(@temp_dir, "combined_master#{ext}")
    list_path = File.join(@temp_dir, "concat_list.txt") # do we use this

    @log_proxy.send_log(recording_id, "Stitching #{files.size} tracks into a single master...")

    # 5. Manifest: Create the text file that tells FFmpeg the order of the tracks
    File.open(list_path, "w") do |f|
      files.each { |path| f.puts "file '#{path}'" }
    end

    # 6. The Stitch: Use the Concat Demuxer with '-c copy' for zero loss
    # -f concat: The demuxer mode
    # -safe 0: Allows the use of absolute file paths
    # -c copy: Re-wraps the packets without re-encoding (instant and lossless)
    cmd = "ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i \"#{list_path}\" -c copy \"#{combined_path}\""
  
    success = system(cmd)

    unless success && File.exist?(combined_path)
      raise "FFmpeg Stitch Failed for Recording ##{recording_id}. Check if files are truly compatible."
    end

    # Return the path to the new single master file
    combined_path
  end
  
  def create_chunks_from_file(job_receipt, file_path, temp_dir)
    # Variables are centralized here
    
    min_split_threshold = 2100 
  
    duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{file_path}"`.to_f
  
    if duration <= min_split_threshold
      create_chunk_metadata(job_receipt, file_path, duration, 0, temp_dir)
      return
    end

    # The loop is moved into this readable private method
    process_file_into_segments(job_receipt, file_path, duration, temp_dir)
  end

  def process_file_into_segments(job_receipt, file_path, duration, temp_dir)
    current_time = 0
    file_prefix = File.basename(file_path, '.*').gsub(/[^\w\.\-\(\)\&]/, '_')

    while current_time < duration
      chunk_len = calculate_next_chunk_length(file_path, current_time, duration)
    
      # Merge small end-of-file slivers
      if (duration - (current_time + chunk_len)) < 300
        chunk_len = duration - current_time
      end

      # This creates the physical file FIRST, then the DB record
      create_chunk_metadata(job_receipt, file_path, chunk_len, current_time, temp_dir, file_prefix)
    
      current_time += chunk_len
    end
  end

  def calculate_next_chunk_length(file_path, current_time, duration)
    base_chunk_size     = 1800 
    search_start = current_time + (base_chunk_size - 5)
    return duration - current_time if (duration - search_start) < 60

    cmd = "ffmpeg -ss #{search_start} -t 10 -i \"#{file_path}\" -af silencedetect=n=-25dB:d=0.4 -f null - 2>&1"
    output = `#{cmd}`
    silence_match = output.match(/silence_start: ([\d\.]+)/)
  
    relative_cut_point = silence_match ? silence_match[1].to_f : 5.0
    (base_chunk_size - 5) + relative_cut_point
  end

  def create_chunk_metadata(job_receipt, file_path, chunk_len, start_time, temp_dir, prefix = nil)
    prefix ||= File.basename(file_path, '.*').gsub(/[^\w\.\-\(\)\&]/, '_')
    dest_path = File.join(temp_dir, "#{prefix}_at_#{start_time.to_i}.wav")

    # 1. PROCESS: Physical file extraction happens here
    success = system("ffmpeg -hide_banner -loglevel error -ss #{start_time} -threads 2 -t #{chunk_len} -i \"#{file_path}\" -ar 16000 -ac 1 -c:a pcm_s16le \"#{dest_path}\"")

    # 2. METADATA: Only save to DB if the file process succeeded
    if success && File.exist?(dest_path)
      job_receipt.wav_chunks.create!(
        file_path: dest_path.to_s,
        original_filename: File.basename(file_path),
        start_time: start_time,
        duration: chunk_len,
        status: :pending
      )
    end
  end
  
  def swap_and_verify_cloud_storage(client:, service_config:, local_path:, s3_metadata:, recording_id:)
    file_name = File.basename(local_path)
    display_name = file_name.gsub('_', ' ')
    new_key = "#{s3_metadata['archive_folder']}/#{file_name}"
    old_key = s3_metadata['key']
    resource_id = s3_metadata['resource_id'] 
    bucket = service_config['bucket']
    
    # 1. UPLOAD the new archive file 
    File.open(local_path, 'rb') do |file|
      client.put_object(bucket: bucket, key: new_key, body: file)
    end

    # 2. VALIDATE 
    if client.head_object(bucket: bucket, key: new_key).content_length == 0
      raise "Cloud Verification Failed: File at #{new_key} is 0 bytes." 
    end

    # 3. UPDATE the specific RESOURCE via the ResourceProxy
    # We target the resource_id directly now.
    digest = Digest::MD5.new
    File.open(local_path, 'rb') do |f|
      while chunk = f.read(65536) # Read in 64k chunks
        digest.update(chunk)
      end
    end
    calculated_checksum = Base64.strict_encode64(digest.digest)
    @resource_proxy.update(resource_id, {
       cloud_upgraded: true,
      active_storage_patch: { 
        key: new_key, 
        filename: display_name,
        byte_size:    File.size(local_path),
        content_type: Marcel::MimeType.for(Pathname.new(local_path)), # Rails' default MIME detector
        checksum:     calculated_checksum
      }
    })

    # 4. REMOVE the original source file 
 #   unless new_key == old_key
      begin
        client.delete_object(bucket: bucket, key: old_key)
        @log_proxy.send_log(recording_id, "🗑️ Cloud: Source #{old_key} removed.")
      rescue => e
        @log_proxy.send_log(recording_id, "⚠️ Cloud: Delete original failed (non-critical): #{e.message}")
      end
 #   end

    @log_proxy.send_log(recording_id, "✅ Cloud: Resource ##{resource_id} swapped and verified.")
  end
  


  def convert_file(file_path:, recording_id:, s3_metadata: )
    Rails.logger.debug "\n\nline 203\n\n"
    @log_proxy.send_log(recording_id, "upgrading files")
    ext = File.extname(file_path).downcase
    archive_folder = s3_metadata['archive_folder']
    title = s3_metadata['title']
    # The server has already done the heavy lifting on the naming and sanitization
    dest_dir = File.join(@archive_storage, archive_folder)
    FileUtils.mkdir_p(dest_dir)

    # Check if the file contains a video stream
    is_video = `ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "#{file_path}"`.strip.include?("video")
    is_h264 =is_video && `ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "#{file_path}"`.strip == "h264"
    in_specs = (ext == ".mp3") || (ext == ".mp4" && is_h264)
    # 1. THE NATIVE PATH: Already MP4 or MP3
    if in_specs 
      archive_path = File.join(dest_dir, "#{title}#{ext}")
      @log_proxy.send_log(recording_id, "Native #{ext} detected. Archiving to #{archive_path}")
    
      FileUtils.cp(file_path, archive_path)
      return archive_path

    # 2. THE RE-WRAP PATH: Non-MP4 Video
    elsif is_video
      archive_path = File.join(dest_dir, "#{title}.mp4")
      @log_proxy.send_log(recording_id, "Non-MP4 video detected. Re-wrapping into #{archive_folder}...")
       
      success = transcode_to_h264(input: file_path, output: archive_path)
      raise "🚫 RE-WRAP FAILED: Could not move #{ext} streams to MP4 for #{title}" unless success
    
      return archive_path

    # 3. THE BYPASS PATH
    else
      raise "🚫 CRITICAL ARCHIVE FAILURE: File format '#{ext}' fails archive specifications for #{title}. Stopping pipeline."
    end
  end
  
  def transcode_to_h264(input:, output:)
    # 1. Probe the source bitrate
    probe_cmd = "ffprobe -v error -select_streams v:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 \"#{input}\""
    source_bps = `#{probe_cmd}`.strip.to_i

    # 2. Logic: Keep original but cap at 2Mbps. 
    # Fallback to 2000k for "non-normal" files where probe fails.
    target_bitrate = source_bps > 0 ? [source_bps, 2_000_000].min : "2000k"

    # 3. Build the Hardware-Accelerated Command
    cmd = [
      "ffmpeg -hide_banner -loglevel error -y",
      "-i \"#{input}\"",
      "-c:v h264_videotoolbox", # M4 Hardware Acceleration
      "-b:v #{target_bitrate}",
      "-profile:v high",
      "-color_primaries bt709",
      "-color_trc bt709",
      "-colorspace bt709",
      "-pix_fmt yuv420p",
      "-c:a aac",              # High-quality audio for the transcription engine
      "-movflags +faststart",   # Better for web-streaming the archive later
      "\"#{output}\""
    ].join(" ")

    # 4. Execute
    Rails.logger.debug "FFmpeg Executing: #{cmd}"
    system(cmd)
  end

  
  def unzip_to_folder(log_proxy, recording_id, zip_file_path, temp_dir)
    extracted_paths = []
     log_proxy.send_log(recording_id,"unzip source files #{Time.now.utc.strftime("%M:%S")}")
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
  
  def is_zip?(path)
    File.extname(path).downcase == '.zip'
  end
  # On the Worker side
  
  def download_source_file(s3_metadata, temp_dir, recording_id,s3_client, service_config)
    Rails.logger.debug "\n\nrun: download_source_file(s3_metadata, @temp_dir, recording_id))\n\n"
    target_path = File.join(temp_dir, s3_metadata['filename'])

    begin
      puts "DEBUG: [M4] Downloading #{s3_metadata['filename']}..."

      # 3. The Transfer
      s3_client.get_object(
        response_target: target_path,
        bucket: service_config['bucket'],
        key: s3_metadata['key']
      )
      puts "line 135"
      # Return the path if successful
      target_path

    # 4. Specific "Remedies" and Error Handling
    rescue Aws::S3::Errors::SignatureDoesNotMatch
      raise "S3 Auth Failed: Signature mismatch. Check credentials/system clock for #{service_name}"

    rescue Aws::S3::Errors::NoSuchKey
      raise "S3 Error: File '#{s3_metadata['key']}' not found in bucket '#{service_config['bucket']}'"

    rescue Seahorse::Client::NetworkingError => e
      raise "Networking Error: Could not connect to #{service_config['endpoint']}. Error: #{e.message}"

    rescue Aws::S3::Errors::AccessDenied
      raise "S3 Error: Access Denied. Check bucket permissions for #{service_name}"

    rescue StandardError => e
      # Catch-all for anything else (disk full, local permissions, etc.)
      raise "Download failed for Recording ##{recording_id}: #{e.message}"
    end
  end
  
  def finalize_failed_transcription(job_receipt:,  error_message:)
    # 1. Local M4 Transaction: Clear chunks and mark as failed
    job_receipt.transaction do
      job_receipt.wav_chunks.delete_all
      job_receipt.update(status: :failed, error_message: error_message)
    end
    begin
      attributes = { transcription_status: :failed }
      puts "base attributes #{attributes}"
      # add job receipt attributes so the server can document the failed job
      attributes[:job_receipts_attributes] = [{
          status: :failed,
          error_message: error_message
        }]
        puts "full attributes #{attributes}"
      @recording_proxy.update(job_receipt.recording_id, attributes)
      
      # Optional: Log the specific failure reason to the server's audit trail
      @log_proxy.send_log(job_receipt.recording_id, "❌ Prep Failed: #{error_message}")
    rescue => e
      Rails.logger.error "[M4] Failed to notify Librarian of job failure: #{e.message}"
    end
    
    # 3. Workspace Cleanup
   # FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
    
    puts "🏁 Finalized failure for Recording ##{job_receipt.recording_id}"
  end
      
  def request_metadata_from_server(job_receipt:, recording_id:)
    Rails.logger.debug "\n\nrun: request_metadata_from_server(job_receipt, recording_id)\n\n"
    data = @recording_proxy.update(recording_id, { transcription_status: :preparing })
    s3_metadata = data["s3_metadata"]
    puts "s3_metadata #{s3_metadata}"
    if s3_metadata['title'].blank?
      error_msg = "Critical Error: title is blank for Recording ##{recording_id}. Aborting job."
      @log_proxy.send_log(recording_id, error_msg)
      # This stops the 'perform' action immediately
      raise StandardError, error_msg 
    end
    if s3_metadata['archive_folder'].blank?
      error_msg = "Critical Error: archive_folder is blank for Recording ##{recording_id}. Aborting job."
      @log_proxy.send_log(recording_id, error_msg)
      # This stops the 'perform' action immediately
      raise StandardError, error_msg 
    end
     
    job_receipt.update!(archive_folder: s3_metadata['archive_folder'], 
                        recording_title: s3_metadata['title'],
                        resource_id: s3_metadata['resource_id'])
    puts "S3 Metadata received for #{s3_metadata['filename']}"
  
    s3_metadata
  end
  
  def prep_workspace(job_receipt,recording_id)
    job_receipt.wav_chunks.delete_all
    job_receipt.preparing! # 1. Update status to 'preparing' locally
     @log_proxy.send_log(job_receipt.recording_id, "😀")
    @log_proxy.send_log(recording_id, "🚀 Starting Prep Job for Recording ##{recording_id}")
  end
  
end