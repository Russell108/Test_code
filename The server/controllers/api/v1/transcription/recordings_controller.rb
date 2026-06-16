
# /app/controllers/api/v1/transcription/recordings_controller.rb
class Api::V1::Transcription::RecordingsController <  Api::V1::Transcription::BaseController
  # Standard API practice: skip CSRF since we use token auth
 
  def index
    # We use the model method to:
        # 1. Find 'requested' records
        # 2. Lock them (SKIP LOCKED)
        # 3. Flip status to :processing
        # 4. Return the batch
        recording_ids = Recording.clean_pipeline_collect_next_recording_ids_for_worker(limit: 5)
      #  recording_ids = Recording.scout_and_collect_ids_for_worker(limit: 5)
      logger.debug "\n\nrecording_ids #{recording_ids}\n\n"
        # We return the ID so the worker can later ask the 
        # ResourcesController for the "Best Resource" (JIT)
        #@recordings = Recording.limit(3)
        render json: { recording_ids: recording_ids }
  end
  
  def update
    @recording = Recording.find(params[:id])
    @recording.editable_when_locked =  ["transcription_status","transcribed_at"]
    logger.debug "\n\nrecording_params #{recording_params}\n\n"
    if @recording.update(recording_params)
      begin
        if @recording.transcription_status == "preparing"
          resource = @recording.best_transcribable_resource
          if resource.nil?
            render json: { success: false, errors: "No valid transcribable resource found" }, status: :not_found
            return
          end
          blob = resource.file.blob
          render json: { 
            success: true, 
            s3_metadata: {
              service_name: blob.service_name,
              key: blob.key,
              byte_size: blob.byte_size,
              title: @recording.safe_title,
              archive_folder: @recording.archive_folder,
              filename: blob.filename.to_s,
              resource_id: resource.id,
              cloud_upgraded: resource.cloud_upgraded
            }
          }
        else
          render json: { success: true }
        end

      rescue Seahorse::Client::NetworkingError, StandardError => e
        # We don't guess—we send the actual message from the exception
        render json: { success: false, errors: e.message }, status: :service_unavailable
      end
    else
      render json: { success: false, errors: @recording.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private
  
  def metadata_for_best_transcribable_resource(recording)
    return { success: true } unless recording.transcription_status == "preparing"
    
    resource = recording.best_transcribable_resource
    
    if resource.nil?
      { 
        success: false, 
        error_type: "MISSING_RESOURCE",
        errors: ["No transcribable resource found. Please upload a downloadable resource."] 
      }
    else
      # We pull only what is stored directly in the active_storage_blobs table
      blob = resource.file.blob
      { 
        success: true, 
        s3_metadata: {
          key: blob.key,              
          service_name: blob.service_name,
          byte_size: blob.byte_size,  
          identifier: recording.identifier
        }
      }
    end
  end
  
 
  def recording_params
    return unless params[:recording]
    safe_attributes =[
            :transcription_status,
            :raw_transcript,
            :caption_file,
            job_receipts_attributes: [:status, :error_message]
        ]
      params.require(:recording).permit(*safe_attributes)
  end
  
  
  #rescue Seahorse::Client::NetworkingError 
  #  logger.debug "\n\nrescue Seahorse::Client::NetworkingError \n\n"
  #  render json: { 
  #  success: false, 
  #  errors: "Could not connect to S3 to generate download URL." ,
  ## error: "storage_connection_failed",
  ## message: "Could not connect to S3 to generate download URL." 
  #}, status: :service_unavailable
  
end
