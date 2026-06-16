# app/services/transcription_log_proxy.rb
class TranscriptionLogProxy < TranscriptionServerBaseProxy
  
  def send_log(recording_id, message)
    # This hits your specific V1 endpoint
    response = connection.post("transcription_logs", { 
      recording_id: recording_id, 
      message: message 
    })

    # Centralized response handling (raises on 422/500)
    handle_response(response)
    
  rescue Faraday::Error => e
    Rails.logger.error "[M4 Log Proxy] Failed to shout: #{e.message}"
    # Raising here instead of returning false ensures the Worker's 
    # rescue block actually triggers to stop the job.
    raise "Librarian Connection Failed: #{e.message}"
  end

end

