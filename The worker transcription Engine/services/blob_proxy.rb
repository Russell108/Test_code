# app/services/blob_proxy.rb
class BlobProxy < TranscriptionServerBaseProxy

  def create(params = {})
    # Note: We are hitting your new, semantic endpoint
    response = connection.post("blobs") do |req|
      req.body = { blob: params }.to_json
    end

    handle_response(response)
  rescue => e
    raise "Librarian Handshake Failed: #{e.message}"
  end

end
