# /services/storage_download_service.rb
class StorageDownloadService
  def self.call(s3_metadata, target_path)
    new(s3_metadata, target_path).execute
  end

  def initialize(s3_metadata, target_path)
    @s3_metadata = s3_metadata
    @target_path = target_path
    @service_name = s3_metadata['service_name']
  end

  def execute
    s3_client.get_object(
      response_target: @target_path,
      bucket: config["bucket"],
      key: @s3_metadata['key']
    )
    @target_path
  rescue => e
    raise "StorageDownloadService Error: #{e.message}"
  end

  private

  def s3_client
    Aws::S3::Client.new(
      access_key_id: config["access_key_id"],
      secret_access_key: config["secret_access_key"],
      region: config["region"],
      endpoint: config["endpoint"],
      force_path_style: true,
       ssl_verify_peer: false
    )
  end

  def config
    @config ||= begin
      # Manually loading because Rails.configuration.active_storage can be nil in workers
      raw_yml = File.read(Rails.root.join("config", "storage.yml"))
      all_configs = YAML.safe_load(ERB.new(raw_yml).result, aliases: true)
      all_configs[@service_name.to_s] || raise("Service #{@service_name} not found in storage.yml")
    end
  end
end