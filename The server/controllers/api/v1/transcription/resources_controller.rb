
# /app/controllers/api/v1/transcription/resources_controller.rb
class Api::V1::Transcription::ResourcesController < Api::V1::Transcription::BaseController

  # /app/controllers/api/v1/transcription/resources_controller.rb
  def update
    @resource = Resource.find(params[:id])
    @resource.editable_when_locked =  ["cloud_upgraded", "locally_archived"]
    begin
      @resource.transaction do
        # 1. Update Resource Attributes (Raises exception on failure)
        @resource.update!(resource_params.except(:active_storage_patch))

        # 2. Update Blob Metadata
        if resource_params[:active_storage_patch]
          patch = resource_params[:active_storage_patch]
          blob = @resource.file.blob

          # Direct update to blob identity
          blob.update_columns(
            key:          patch[:key],
            filename:     patch[:filename],
            byte_size:    patch[:byte_size],
            content_type: patch[:content_type],
            checksum:     patch[:checksum]
          )

          # 3. Refresh the attachment
          @resource.file.attach(blob)
        end
      end

      # Success: Transaction committed
      render json: { success: true, resource_id: @resource.id }

    rescue ActiveRecord::RecordInvalid => e
      # Caught if @resource.update! fails validation
      render json: { success: false, error: "Validation failed: #{e.record.errors.full_messages.join(', ')}" }, status: :unprocessable_entity
    rescue => e
      # Caught if blob update_columns or anything else explodes
      render json: { success: false, error: "Transaction failed: #{e.message}" }, status: :internal_server_error
    end
  end

  private

  def resource_params
    # Security Layer: We explicitly define the allowed shape of the patch.
    # This prevents 'unpermitted parameters' and keeps the API secure.
    params.require(:resource).permit(
      :cloud_upgraded,
      :locally_archived ,
      active_storage_patch: [:key, :filename,:byte_size, :content_type, :checksum ]
    )
    
    
  end
end

