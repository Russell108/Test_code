# app/services/cloud_proxy.rb
class CloudProxy
  def self.upload(ticket, file_data)
    puts "--- CLOUD PROXY: STARTING UPLOAD ---"
    puts "DEBUG: RAW TICKET CLASS: #{ticket.class}"
    puts "DEBUG: TICKET KEYS: #{ticket.keys.inspect}"

    # Safely extract data using strings, since JSON.parse usually returns string keys
    direct_upload = ticket['direct_upload'] || ticket[:direct_upload]
    
    if direct_upload.nil?
      puts "ERROR: direct_upload key is NIL. Full ticket: #{ticket.inspect}"
      return false
    end

    url = direct_upload['url']
    headers = direct_upload['headers']

    puts "DEBUG: TARGET URL: #{url&.split('?')&.first}... [truncated]"
    puts "DEBUG: TARGET HEADERS: #{headers.inspect}"

    # Perform the PUT request to S3/Linode
    # Note: We use a raw Faraday connection here because S3 expects 
    # a PUT with the exact headers provided in the handshake.
    response = Faraday.put(url, file_data, headers)

    puts "DEBUG: CLOUD STORAGE RESPONSE STATUS: #{response.status}"
    
    if response.success?
      puts "--- CLOUD PROXY: UPLOAD SUCCESS ---"
      true
    else
      puts "--- CLOUD PROXY: UPLOAD FAILED ---"
      puts "DEBUG: BODY: #{response.body}"
      false
    end
  end
end