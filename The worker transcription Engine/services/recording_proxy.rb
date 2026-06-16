# app/services/recording_proxy.rb
class RecordingProxy < TranscriptionServerBaseProxy
  
  # Step 1: The Menu
#  def index_for_next_recordings(limit: 5)
#    response = connection.get("recordings", { limit: limit })
#    
#    # We use handle_response here too to catch 500s/401s
#    body = handle_response(response)
#    body['recording_ids'] || []
#  rescue => e
#    Rails.logger.error "🚨 [M4] Scout failed: #{e.message}"
#    [] # For the index, returning an empty list is safer than crashing the worker loop
#  end
  
  def index_for_next_recordings(limit: 5)
      response = connection.get("recordings", { limit: limit })
    
      # We use handle_response here too to catch 500s/401s
      body = handle_response(response)
      body['recording_ids'] || []
    rescue Faraday::Error => e
      # 🌟 MIRRORS THE UPDATE PATTERN PERFECTLY:
      # Instead of swallowing the error and returning [], we log it and raise!
      Rails.logger.error "🚨 [M4] Connection error during scout: #{e.message}"
      raise "Librarian Connection Failed: #{e.message}"
    end

  # Step 2: The Handshake
  def update(id, attributes = {})
    Rails.logger.info "\n\n[M4] Updating Recording #{id} with #{attributes}\n\n"
    
    # Note: Ensure attributes are wrapped in a 'recording' key if your 
    # Server controller uses recording_params (e.g., params.require(:recording))
    response = connection.patch("recordings/#{id}", { recording: attributes })

    # 🚀 This is the critical change:
    # If the server returns 422 (Validation Error), handle_response will RAISE.
    # This triggers the 'rescue' block in your TranscriptionPrepJob.
    handle_response(response)
    
  rescue Faraday::Error => e
    Rails.logger.error "🚨 [M4] Connection error for ID #{id}: #{e.message}"
    raise "Librarian Connection Failed: #{e.message}"
  end
  
  

  private
  

  
end