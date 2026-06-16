# app/services/resources_proxy.rb
class ResourceProxy < TranscriptionServerBaseProxy

  # app/services/resources_proxy.rb


  
  # This hits your NEW ResourcesController#update
  def update(id, attributes = {})
    Rails.logger.info "\n\n[M4] Updating Resource #{id} with #{attributes}\n\n"
  
    # Note: Wrapped in 'resource' key for the server-side controller
    response = connection.patch("resources/#{id}", { resource: attributes })

    handle_response(response)
  rescue Faraday::Error => e
    Rails.logger.error "🚨 [M4] Connection error for Resource ID #{id}: #{e.message}"
    raise "Librarian Connection Failed: #{e.message}"
  end
  

  
end