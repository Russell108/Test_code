# app/services/transcription_server_base_proxy.rb
class TranscriptionServerBaseProxy
  def initialize
    @base_url = Rails.configuration.x.transcription_server_url
    @token = Rails.application.credentials.m4_api_token
  end

  protected

  def connection
    @connection ||= Faraday.new(url: @base_url) do |f|
      f.request :json
      # We skip f.response :json here because you are doing JSON.parse 
      # manually in handle_response. If you keep f.response :json, 
      # response.body will already be a Hash, and JSON.parse will fail.
      
      f.headers['Authorization'] = "Bearer #{@token}"
      f.headers['Content-Type'] = 'application/json'

      if Rails.env.development?
        f.ssl[:verify] = false 
      end

      f.adapter Faraday.default_adapter
    end
  end
  
  private
  
#  def handle_response(response)
#    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
#
#    if response.success?
#      body || {}
#    elsif [422, 503].include?(response.status)
#      # This handles both validation errors and the S3 Seahorse networking errors
#      errors = Array(body["errors"]).join(", ")
#      errors = "Unknown Server Error" if errors.empty?
#      raise "Server Error (#{response.status}): #{errors}"
#    else
#      raise "Server Error: #{response.status} - #{response.body}"
#    end
#  rescue JSON::ParserError
#    raise "Server Error: #{response.status} (Non-JSON response)"
#  end
  
  def handle_response(response)
    # Standard JSON parsing
    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
   # Rails.logger.debug "\n\nresponse.inspect\n\n"
   # Rails.logger.debug "\n\nbody #{body}\n\n"
    if response.success?
      body || {}
    elsif [422, 503].include?(response.status)
      # 1. Try plural 'errors' first, then look for singular 'error'
      error_data = body["errors"] || body["error"]
      
      # 2. Safely turn it into a readable string
      errors = error_data.is_a?(Array) ? error_data.join(", ") : error_data.to_s
      
      # 3. Fallback only if both keys were completely missing or empty
      errors = "Unknown Server Error" if errors.blank?
      
      raise "Server Error (#{response.status}): #{errors}"
    else
      raise "Server Error: #{response.status} - #{response.body}"
    end
 #rescue JSON::ParserError
 #  # THIS IS THE KEY: We print the raw response to find out WHY it's not JSON
 #  # Check your terminal/logs for the "RAW SERVER OUTPUT" line.
 #  puts "DEBUG: RAW SERVER OUTPUT (First 500 chars): #{response.body.to_s[0..500]}"
 #
 #  raise "Server Error: #{response.status} (Non-JSON response) - See logs for HTML"
  rescue JSON::ParserError
    # Search the HTML for the "message" or "exception" 
    error_snippet = response.body.match(/<title>(.*)<\/title>/)&.[](1) || "Unknown HTML Error"
    puts "CRITICAL SERVER ERROR: #{error_snippet}"
  
    # Log the whole thing to a file so you can open it in a browser
    File.write("error_debug.html", response.body)
  
    raise "Server Error: #{response.status} - Look at error_debug.html"
  end
  
  
end