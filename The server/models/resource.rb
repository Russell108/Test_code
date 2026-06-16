class Resource < ApplicationRecord

#====================================   Notes   ===============================================

	has_one_attached :file
  
  include Lockable



#====================================  callbacks    ===============================================
  before_validation :assess_file_extension , :on => :create,   :if => Proc.new { |r| r.file.attached?}
 
  around_save :cart_resources, if: Proc.new { |resource| resource.purchasable ==false} 
  before_destroy :verify_destroy
#====================================   relationships   ===============================================
	belongs_to :recording, :inverse_of => :resources, optional: true

  belongs_to :format, optional: true
	belongs_to :bucket, optional: true
	belongs_to :talk_type, optional: true
  
  has_many :bundle_items , as: :bundleable
  
	has_many	:acquired_resources, :dependent=>:destroy
	has_many :order_items , as: :orderable, :dependent => :destroy, :inverse_of =>:resource
	
	has_many :allocated_orders, :through => :ordered_resources
	
	
	delegate :happening , :to => :recording


  
#====================================   Validations   ===============================================
	
	validates_presence_of :format_id
#	validates_presence_of :bucket_id,	:message => "Bucket not set!! Please check with support",:if => Proc.new{ |res| (res.format && res.format.downloadable )}
	validates_uniqueness_of :format_id, :scope => :recording,
                            :message => " already exists for this recording!!"

 	validate :uploaded_on_server ,:if => Proc.new{ |res| res.uploaded_changed? && res.uploaded } 
 	
 	
 	
  validates_inclusion_of :format_id, in: :current_format_ids,
  							message: "is not a currently available Format",
  									  :if => Proc.new { |r| r.new_record? and r.format_id }   
    
#====================================   Scopes   ===============================================
	scope :by_format,lambda{|format_id | where(:format_id =>format_id)}
	scope :by_happening,lambda{| happening_id| 
  		where(recordings:{:happening_id =>happening_id}).joins(:recording)
  }
  
	scope :by_package,lambda{| package| 
  		where("recordings.happening_id =? and resources.format_id = ?",package.happening_id, package.format_id ).joins(:recording)
  }
 	
 	scope :purchasable,->{  where(:purchasable =>true)}
  
 	scope :by_area,->(area_id) { 
		 where("happenings.happenable_id = ? AND happenings.happenable_type = ?",area_id, "Area").joins(:recording=>:happening)
  }
 	
  scope :by_happening_centre,->(centre_id) { 
		 where("happenings.happenable_id = ? AND happenings.happenable_type = ?",centre_id, "Centre").joins(:recording=>:happening)
  }
	
  scope :by_course_centre,->(centre_id) { 
		 where("courses.centre_id = ? AND happenings.happenable_type = ?",centre_id, "Course")
		 .joins(recording: {happening: :course})
  }

	scope  :downloadable ,->{  where("formats.downloadable is true").joins(:format)
  }

	# Be wary the following scopes ause pluck
	scope :purchasable_plucked_by_happening ,  lambda{|happening_id |joins(:recording,:format)\
			.where("recordings.happening_id =? and resources.purchasable is true", happening_id )
			.group("resources.recording_id")\
			.pluck(Arel.sql("resources.recording_id,array_agg(array[resources.id::text, formats.name::text]) "))
	}
  
   scope :with_attached_file, -> { joins(:file_attachment) }
  # =============================================================================================
  # for happening acquirerships controller
  	scope :acquireable_plucked_by_happening ,  lambda{|happening_id |joins(:recording,:format)\
  			.where("recordings.happening_id =? and formats.downloadable is true and resources.talk_type_id != 4", happening_id )
  			.group("resources.recording_id")\
  			.pluck(Arel.sql("resources.recording_id,array_agg(array[resources.id::text, formats.name::text]) ")).to_h
  	}
  
  	scope :grouped_acquireable_plucked_for_happenings ,  lambda{|happening_ids |joins(:recording,:format)\
  			.where("recordings.happening_id in(?) and formats.downloadable is true and resources.talk_type_id != 4", happening_ids )
  			.group("resources.recording_id")\
  			.pluck(Arel.sql("resources.recording_id,array_agg(array[resources.id::text, formats.name::text]) ")).to_h
  	}

  #====================================   Public Class Methods   ===============================================


   	#  get resources which users have access to through acquired Packages & acquired resources 
    # deleted 3/8/2021
   
    scope :happening_acquired_resources_by_user, lambda{|user_ids, happening_id | joins( acquired_resources: {resource: :recording})\
      .where("acquired_resources.user_id in (?) and recordings.happening_id =? ", user_ids, happening_id)\
      .group("acquired_resources.user_id")\
      .pluck(Arel.sql("acquired_resources.user_id, array_agg(array[acquired_resources.resource_id::text, acquired_resources.id::text, acquired_resources.order_id::text] )"))
    }
     
 
   



    def self.plucked_happening_carted_resources_by_user(user_ids, happening_id)
        plucked_carted_resources = self.joins(:format,{order_items: :order})
        .group("orders.user_id, resources.recording_id")
        .where("orders.user_id in (?) and orders.type =? and orders.happening_id =?", user_ids,'Cart', happening_id)
        .pluck(Arel.sql("orders.user_id,resources.recording_id, array_agg(array[ order_items.orderable_id, order_items.id])"))
   
      plucked_carted_resources_to_hash =   three_element_nested_array_to_nested_hash( plucked_carted_resources )   
    end
  


    def self.plucked_happening_purchased_resources_by_user(user_ids, happening_id)
        plucked_carted_resources = self.joins(:format,{order_items: :order})
        .group("orders.user_id")
        .where("orders.user_id in (?) and orders.type =? and orders.happening_id =?", user_ids,'ProcessedOrder', happening_id)
        .pluck(Arel.sql("orders.user_id, array_agg( order_items.orderable_id)"))
   
      plucked_carted_resources_to_hash =   plucked_carted_resources.to_h  
    end
  
    def self.resource_ids_by_bundle_ids(bundle_ids)
      self.left_outer_joins(:bundle_items,recording:{ happening: {packages: :bundle_items}} )\
      .where("(bundle_items.bundle_id in (?))OR (bundle_items_packages.bundle_id in (?) and resources.format_id = packages.format_id)", bundle_ids, bundle_ids)
      .pluck(Arel.sql("resources.id"))
    end

  
 

  
  
    def self.plucked_and_grouped_in_bundles_for_sales_mailer(bundle_ids)
      resources= self.joins(:format,:recording, :bundle_items)
      .group('bundle_items.bundle_id','recordings.number','recordings.title','recordings.start_datetime','recordings.content')
      .where("bundle_items.bundleable_type = ? and bundle_items.bundle_id in (?)",'Resource', bundle_ids )
      .pluck(Arel.sql("bundle_items.bundle_id,
          ARRAY[recordings.start_datetime::text, CONCAT_WS(' ', recordings.number::text, recordings.title::text ), recordings.content::text , string_agg(formats.name , ',')]")) 
          resources.inject(Hash.new{ |h,k| h[k]=[] }){ |h,(k,v)| h[k] << v; h }
    end
  
#====================================   Public Instance Methods   ===============================================
#{bundle_items: {bundle: {order_items: :order}}} ,
	def format_name
		("&nbsp;" + format.name + "&nbsp;&nbsp;").html_safe
	end	

  def available_for_download
    message=""
    if file.attached?
      active_Storage_upload_array = download_link_from_active_Storage_upload
      if  active_Storage_upload_array
        url = active_Storage_upload_array[0]
        message =active_Storage_upload_array[1]
      else
        url=false
      end
   
    end
    return [url, message]
  end
  
 


  def editable_when_locked
    # If a dynamic array was assigned in the console, use it. 
    # Otherwise, fall back to your hardcoded default array.
    @dynamic_editable_fields || ["purchasable"] 
  end
 

  def editable_when_locked=(array)
    # Convert everything to strings to ensure it plays nice with Lockable
    @dynamic_editable_fields = Array(array).map(&:to_s)
  end



  def my_logger
    @@my_logger ||= Logger.new("#{Rails.root}/log/manual2aws.log")
  end
  
 
  
 
  

  

  
  #. for deletion
#  def aws_client_options
#  
#    options={}
#    access_key_id_key    =  self.bucket.name.split('-').join('_') + "_access_key_id"
#    secret_access_key_key = self.bucket.name.split('-').join('_') + "_secret_access_key"
#    access_key_id= Rails.application.credentials.aws[access_key_id_key.to_sym]
#    secret_access_key= Rails.application.credentials.aws[secret_access_key_key.to_sym] 
#    if (access_key_id.blank? or secret_access_key.blank?)    
#      self.errors.add(:base, "S3, bucket credentials not set!!")
#      return false 
#    end
#   
#      options = {endpoint: "https://eu-central-1.linodeobjects.com",
#                region: bucket.region.name,
#                access_key_id:       access_key_id ,
#                 secret_access_key:  secret_access_key
#                }
# 
#    return options
#  end
#====================================   Private Methods   ===============================================
	private
  
  # used for muigration
  
	def uploaded_on_server
		if file.attached? 
			unless(file.blob.service.exist?(file.key))
				errors.add(:base,  "file missing on Active Storage") 
      else 
        return 
			end
    else 
      errors.add(:base,  "no file attached") 
		end
	end
 
  
#   def process_video(_file_path)
#     filename =   "S#{recording.number} #{recording.title}.mp4"  
#     File.open(_file_path) do |file|
#       movie = FFMPEG::Movie.new(file.path)
#       path = "tmp/conversions_for_activestorage/#{filename}"
#      # movie.transcode(path, { video_codec: 'libx264', audio_codec: 'aac' })
#      movie.transcode(path){ |progress| puts progress }
#      new_filename = "S" + recording.number + " " + recording.title + filename.split(".")[1]
#      file.attach(io: File.open(path), filename:new_filename, content_type: 'video/mp4')
#      
#     end
#   end
  
  def get_aws_s3_filename(_s3)
    obj_exists = false
    file_name = "file not found"
    #return object if it exists
    case format_id
    when 1
      filename1 = (recording.happening_id.to_s + "_Session_" + recording.number.to_s+ ".mp3")
      filename2 = (recording.happening_id.to_s + "_Session_" + recording.number.to_s + ".zip")
      if( obj= _s3.bucket(self.bucket.name).object(filename1)).exists?
        obj_exists = true
        file_name = filename1
      elsif (obj= _s3.bucket(self.bucket.name).object(filename2)).exists?
        obj_exists = true
        file_name = filename2
      else
        obj_exists =false
      end
    when 2
      filename1 = (recording.happening_id.to_s + "_Movie_" + recording.number.to_s+ ".m4v")
      filename2 = (recording.happening_id.to_s + "_Movie_" + recording.number.to_s + ".zip")
      if( obj= _s3.bucket(self.bucket.name).object(filename1)).exists?
        obj_exists = true
        file_name = filename1
      elsif (obj= _s3.bucket(self.bucket.name).object(filename2)).exists?
        obj_exists = true
        file_name = filename2
      else
        obj_exists =false
        
      end
			
    else
      obj_exists = false
    end	
    
     
    return [obj_exists, file_name]
  end
  
  def download_file_from_aws(client, file_path, filename)
    File.open(file_path, 'wb') do |file|
      reap = client.get_object({ bucket:self.bucket.name, key: filename }, target: file)
    end
  end
  
  
  
  
  ###############################



  def assess_file_extension
		extension = file.filename.extension
      allowed_types =AllowedFileType.by_format(format_id).collect(&:title)
			unless allowed_types.include? extension.downcase
	 		errors.add(:file, "only #{allowed_types.join(', ')} files allowed")
			end  
  end


  def download_link_from_active_Storage_upload
    if file.blob.service.exist?(file.key)
      return  [file.url, active_storage_download_message()]
    else
      logger.debug "\n\n no service exists\n\n"
      return false
    end
  end
  
  
  def active_storage_download_message()
    case format_id
      when 1
      	 ("Title: " + file.filename.base +
         "\n\n\r<BR><BR>The file will download as a #{file.filename.extension_without_delimiter}. Playable in many media players. " +
        "For example apple music or VLC palyer ")
      when 2
      	("Title: " + file.filename.base + "<BR><BR>The file will download as an Moviefile, playable in many media players. " +
        "For example apple music, quicktime or VLC palyer ")
      else
      	"no message"
    end
  end
  
  #drusound_manual_access_key_id
  #drusound_manual_access_key_id:  	 







	def download_in_bucket?(_s3,name1,name2)
		download_exists =false
		if _s3.bucket(self.bucket.name).object(name1).exists?
			(download_exists = true)
	
		elsif  _s3.bucket(self.bucket.name).object(name2).exists?
			(download_exists = true)
		
		end

	
		return download_exists	
	end

	def assess_format_as_acquireable_and_set_bucket
		(return false) unless format_id
		logger.debug "\n\n:assess_format_as_acquireable_and_set_bucket\n\n"
		 # if format is not downloadable ensure resource cannot be acquirable
		(self.talk_type_id =nil) unless self.format.downloadable

		# if format is downloadable ensure resource bucket is set to centre Bucket
		# if format is locally storeable allow object to set bucket
		# else set bucket_id to nil

		if self.format.downloadable
			if self.recording.happening.happenable_type =="Course"
				self.bucket_id = self.recording.happening.course.centre.bucket_id
			else
				self.bucket_id = self.recording.happening.happenable.bucket_id
			end
		else
				self.bucket_id = nil
		end
		
	end




  def stop_all
    errors.add(:base,  "we will stop you" )
    validate_destroy=    false
  end

  def current_format_ids
    if (recording and recording.happening)
      case happening =recording.happening
      when Meet
        f= Format.current_by_centre(happening.happenable.centre_id).ids
      else
        f= Format.current_by_centre(happening.happenable_id).ids
      end
    else
      f= []
    end

	
    return f
  end


	def cart_resources
		yield
    logger.debug "\n\nwe got here remove_cart_resources\n\n"
		order_items.joins(:order).where("orders.type=?", 'Cart').delete_all
	end


	def  verify_destroy
		allow_destroy=   true

    if ((ar_size =  acquired_resources.size) >0)
			errors.add(:base, "Resource has been acquired by #{ar_size} #{ "person".pluralize(ar_size)}.")
         	allow_destroy=   false
    end
    unless bundle_items.empty?
        errors.add(:package, "#{format.name}:  is part of a Bundle") 
       allow_destroy= false
    end
		(throw :abort )unless allow_destroy
	end

  def self.nested_array_to_hash(nested_array)
    h = Hash.new{ |h,k| h[k]=[] }
    nested_array.each{ |k,v| h[k] << v.flatten }
    h.each { |k, v| h[k] = v.flatten } 
    return h
  end 

  def self.three_element_nested_array_to_nested_hash(nested_array)
    h = Hash.new{ |h,k| h[k]=[] }
    nested_array.each{ |k,v,w| h[k] << [v,w] }
    h.each do |k,v|
      subh=Hash.new(0)
      v.each do |md_array|
          subh[md_array[0]] = md_array[1].to_h
      end
      h[k]=subh
    end     
    return h
  end

  def self.nested_array_to_nested_hash(nested_array)
       h = Hash.new{ |h,k| h[k]=[] }
       nested_array.each{ |k,v| h[k] << v }
      h.each { |k, v| h[k] = v.to_h } 
      return h
  end

  def set_file_name
    format= (format_id == 1) ? "_Session_" : "_Movie_"
    name_for_drusound = recording.happening_id.to_s + format + recording.number.to_s + 
    file.filename.extension_with_delimiter
    (file.filename = name_for_drusound) unless (file.filename == name_for_drusound)
    logger.debug "\n\n file_name #{ name_for_drusound}\n\n"
  end
  
  def manual_download_message(file_type)
    case file_type
      when "Audio.mp3"
      	 ("The file will download as an Audio .mp3 file, playable in most media players. " +
         "The file might contain chapter markers, bookmarks which can be view in any player that supports " +
         "chapterised MP3, for example Downcast.")
      when "Audio.zip"
      	("The file will download as a zipped file. You might need to unzip the file on your computer before playing. " +
      	 "Once unzipped it will appear as a folder containing an Album of .mp3 files." +
      	 "To play add this unzipped folder to your music/media library")
      when "Movie.m4v"
      	("The file will download as an Movie .m4v file, playable in many media players. " +
        "For example itunes or VLC palyer ")
      when "Movie.zip"
      	("The file will download as a zipped file. You might need to unzip the file on your computer before playing. " +
      	 "Once unzipped it will appear as a Movie file. playable in many media players. " +
         "For example itunes or VLC palyer ")
      else
      	"no message"
    end
  end
end



