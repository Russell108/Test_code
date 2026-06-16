# app/controllers/api/v1/transcription/blobs_controller.rb
class Api::V1::Transcription::BlobsController <  Api::V1::Transcription::BaseController

  # Your BaseController handles the token/auth
  
  def create
    # 1. We trust the key because the request is authenticated
    blob = ActiveStorage::Blob.find_or_initialize_by(key: params[:blob][:key])
     blob.service_name = :raw_transcripts if blob.new_record?
    # 2. Update and return the ticket
    if blob.update(blob_params)
      render json: {
        signed_id: blob.signed_id,
        direct_upload: {
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload
        }
      }
    end
  end
  
  private
  
  def blob_params
    params.require(:blob).permit(:key, :filename, :byte_size, :checksum, :content_type)
  end
end
