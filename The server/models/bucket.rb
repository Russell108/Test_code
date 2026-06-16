# add validation if amazon is not available

class Bucket < ApplicationRecord
  # broadcasts_to ->(bucket) { :buckets }

  strip_attributes :collapse_spaces => true 
  
  #=====================  callbacks #=====================
  
  before_destroy :verify_destroy


  #=====================  associations #=====================

  has_many :centres
  has_many :resources
  belongs_to :region
  belongs_to :aws_account_endpoint, class_name: 'AwsEndpoint'
  belongs_to :aws_subdomain_endpoint, class_name: 'AwsEndpoint', optional: true
  
  
 # belongs_to :aws_account
  
   #===================== validations #=====================
  validates_uniqueness_of :name
  validates_presence_of :name, :credential_prefix
  
  #validate :bucket_connection_details, :if => Proc.new { |bucket| !bucket.region.blank? and !bucket.name.blank?}
  validate :bucket_exists_and_accessable_through_account_endpoint , :if => Proc.new { |bucket| !bucket.name.blank? and 
   !bucket.region.blank?  and !aws_account_endpoint_id.blank? and bucket.aws_subdomain_endpoint_id.blank?}
   validate :bucket_exists_and_accessable_through_subdomain_endpoint , :if => Proc.new { |bucket| !bucket.name.blank? and 
    !bucket.aws_subdomain_endpoint_id.blank? and !bucket.region.blank?  and !aws_account_endpoint_id.blank?}
   validate :validate_credential_prefix, :unless => Proc.new { |bucket| bucket.credential_prefix.blank?}
  #===================== public methods #=====================

 



  #===================== private methods #=====================

  private
  
  def validate_credential_prefix
    result =true
    unless (credential_keys - Rails.application.credentials.aws.keys).empty?
      self.errors.add(:credential_prefix, "invalid. Does not match Rails.application.credentials.aws keys")
      result= false 
    end
    return result
  end
  
  def credential_keys
    access_key_id    =  credential_prefix + "_access_key_id"
    secret_access_key_id = credential_prefix + "_secret_access_key"
   
    return [access_key_id.to_sym,secret_access_key_id.to_sym]
  end

  def aws_client_options
    options={}
    access_key_id_key    =  self.name.split('-').join('_') + "_access_key_id"
    secret_access_key_key = self.name.split('-').join('_') + "_secret_access_key"
    access_key_id= Rails.application.credentials.aws[access_key_id_key.to_sym]
    secret_access_key= Rails.application.credentials.aws[secret_access_key_key.to_sym] 
    if (access_key_id.blank? or secret_access_key.blank?)    
      self.errors.add(:base, "S3, bucket credentials not set!!")
      return false 
    end
     
      options = {endpoint: "https://eu-central-1.linodeobjects.com",
                region: region.name,
                access_key_id:       access_key_id ,
                secret_access_key:  secret_access_key
                }
   
    return options
  end

  def verify_destroy
      allow_destroy =true
    unless (self.centres.empty? )         
        errors.add(:bucket, "is being used by a centre")
        allow_destroy=   false
    end
    
    if (used_by_active_storage )         
        errors.add(:bucket, "used by active storage service")
        allow_destroy=   false
    end
    
    unless (self.resources.empty? )         
        errors.add(:bucket, "contains resources")
        allow_destroy=   false
    end    
    
      errors.add(:bucket, "brick wall")
        allow_destroy=   false
     (throw :abort )unless allow_destroy
  end
  
  
  def used_by_active_storage
     result=false
     logger.debug "\n\n check if used by active storage\n\n"
     raw_config = File.read("#{Rails.root}/config/storage.yml")
     storage_cofig = YAML.load(raw_config)
     configured_buckets = []
      storage_cofig.keys.each do |k|
         configured_buckets << storage_cofig[k]['bucket']
      end
      configured_buckets.compact
    
     simple_name =(self.name.split".")[0]
    
     logger.debug "\n\n configured_buckets include #{configured_buckets.include? simple_name}\n\n"
      (result = true )if (configured_buckets.include? self.name)
      (result = true) if (configured_buckets.include? simple_name)
      
      return result
  end
  
  def bucket_exists_and_accessable_through_account_endpoint
    result=true
    return unless validate_credential_prefix
    
    return false unless(client = m(aws_account_endpoint.name,:aws_account_endpoint))
  #  return false unless( buckets = check_for_bucket_in_client_buckets(client))
    
  end
  
  def bucket_exists_and_accessable_through_subdomain_endpoint
    result=true
    return unless validate_credential_prefix
   
    return false unless(client = create_aws_client_for_endpoint(aws_subdomain_endpoint.name,:aws_subdomain_endpoint))
 #   return false unless( buckets = check_for_bucket_in_client_buckets(client,:aws_subdomain_endpoint))
    logger.debug("\n\nry to create resource for bucket\n\n")
    
    return false unless( check_for_bucket_using_subdomain_endpoint(client))
     
     #  logger.debug("\n\obj #{obj}\n\n")
  end
  
  def check_for_bucket_using_subdomain_endpoint(client)
    logger.debug "\n\ncheck_for_bucket_using_subdomain_endpoint(\n\n"
    begin
    obj = client.head_bucket(bucket: name.split('.')[0])
    rescue Aws::Errors::NoSuchEndpointError
      self.errors.add(:name, "Aws::Errors::NoSuchEndpointError")
       return false
     rescue Aws::S3::Errors::NotFound 
       self.errors.add(:name, "Aws::S3::Errors::NotFound")
        return false   
      rescue Seahorse::Client::NetworkingError 
        self.errors.add(:name, "Seahorse::Client::NetworkingError 443. Does the bucket have a SSL certificate?" )
         return false 
    end
  end
  
  def credentials_for_bucket
    
    access_key= Rails.application.credentials.aws[credential_keys[0]]
    secret_key= Rails.application.credentials.aws[credential_keys[1]]
      
    return [access_key, secret_key]
      	 
  end
  
  def check_for_bucket_in_client_buckets(client)
    begin
     response = client.list_buckets
    rescue Aws::S3::Errors::SignatureDoesNotMatch
      self.errors.add(:credential_prefix, "Aws::S3::Errors::SignatureDoesNotMatch")
       return false
     rescue Aws::S3::Errors::InvalidAccessKeyId
       self.errors.add(:credential_prefix, "Aws::Errors::InvalidAccessKeyId")
        return false
    rescue Aws::Errors::NoSuchEndpointError 
      self.errors.add(:name, "Aws::Errors::NoSuchEndpointError")
       return false
     
    
    end
    unless (response.buckets.map(&:name).include? name)
       self.errors.add(:name, "bucket not found")
        return false
    end
   
  end
  
  def create_aws_client_for_endpoint(endpoint, endpoint_column)
    begin  
      Aws::S3::Client.new({endpoint: "https://drusound.com",
                          region: region.name,
                          access_key_id: credentials_for_bucket[0],
                          secret_access_key:credentials_for_bucket[1] 
                          })
      rescue ArgumentError
        self.errors.add(endpoint_column, "expected :endpoint to be a HTTP or HTTPS endpoint")
        return false
      rescue Aws::Errors::MissingRegionError
         self.errors.add(:region, "Aws::Errors::MissingRegionError")
         return false
      rescue Aws::S3::Errors::InvalidAccessKeyId
        self.errors.add(endpoint_column, "Aws::Errors::InvalidAccessKeyId")
        return false
      rescue Seahorse::Client::NetworkingError 
        self.errors.add(:name, "Seahorse::Client::NetworkingError Failed to open TCP connection to avarares.drusound.com:443" )
        return false
      end
  end
  
  def bucket_connection_details
     return false 
    client = Aws::S3::Client.new(aws_client_options )
    s3 = Aws::S3::Resource.new(client: client) rescue nil
    bucket_valid =true
    begin
  result=   client.head_bucket({bucket: name, use_accelerate_endpoint: false})
  logger.debug("\n\nresult #{result.inspect}\n\n")
    rescue StandardError
     bucket_valid =false
    end
    unless bucket_valid  
      self.errors.add(:base, "Cannot connect to AWS S3, bucket credentials invalid!!")
      return false
    end
  	
  end
  
   
end

