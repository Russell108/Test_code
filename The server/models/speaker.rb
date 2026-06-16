class Speaker < ApplicationRecord
	strip_attributes :collapse_spaces => true
  

	#====================================   Call backs   ==================================== 
	before_validation :titleize_name 
	#before_validation  :ensure_stage_name, :if => Proc.new{ |s|  s.stage_name.blank? }

	before_destroy :verify_destroy

#	after_update :crop_avatar, unless: Proc.new{ |speaker|  speaker.avatar.file.nil? }
	#===================   associations   ===================================
	belongs_to :user , optional: true
	has_many :contributions
  has_one_attached :avatar, service: :linode_avatars ## :linode_avatars :linode_avatars_staging##
    
   
	#====================================   validations  ====================================
	validates_presence_of  :stage_name
	validates_uniqueness_of :user, allow_nil: true, message: Proc.new { |error, attributes| 
                         								 "A user can only be connected to one speaker"
                      										  }
	validates_uniqueness_of :stage_name
	#====================================   scopes        ===================================
	scope :by_any_name,lambda{|name | where("forename ILIKE ? or surname ILIKE ? or stage_name ILIKE ?",
	                                               "%#{name}%","%#{name}%", "%#{name}%")}
	scope :split_by_any_name,lambda{|name_0, name_1 | where("(forename ILIKE ? or surname ILIKE ? or stage_name ILIKE ?) and 
															 (forename ILIKE ? or surname ILIKE ? or stage_name ILIKE ?)",
	                                               "%#{name_0}%","%#{name_0}%", "%#{name_0}%","%#{name_1}%","%#{name_1}%", "%#{name_1}%")}



 scope :speakers_for_recordings_render, lambda {|rec_ids|                                                 
          joins(:contributions)
  	      .where(contributions:{recording_id: rec_ids})\
  	      #.where.not(avatar: nil)
          .distinct}
          

         
  scope :speakers_for_recordings, ->(rec_ids) {
    joins(contributions: :recording)
      .where(contributions: { recording_id: rec_ids })
      .select('speakers.*, recordings.happening_id AS speaker_happening_id')
      .with_attached_avatar
      .distinct
  }
  


	#====================================   Public Methods   ===============================================
	def full_name
		full_name = []
		full_name << title   unless    title.blank? 
		full_name << forename  unless forename.blank?
		full_name << surname unless surname.blank?
		full_name = full_name.join( " ")		
	end
  
	def orientation
     orientation = 1
   case deg
     when 180
       orientation =3
     when 90
       orientation =6
     when 270
       orientation =8
   end
   return orientation
 	end

 	def orientation=(_orientation)
    logger.debug "\n\n _orientation #{_orientation} \n\n"
   
    # croppie js
   # 1 unchanged
   # 3 rotated 180 degrees
   # 6 rotated clockwise by 90 degrees
   # 8 rotated cclockwise by 270 degrees
    case _orientation.to_i
      when 3
        deg =180
      when 6
        deg =90
      when 8
        deg =270
      else
        deg =0
    end
    self.deg = deg
 	end
  
  def crop_geometry
   
    return [crop_x,crop_y,crop_w,crop_h] # crop_x, crop_y, crop_w, crop_h
  end
  
  
  
#	def crop_size_offset
#    x = crop_x.to_s
#    y = crop_y.to_s
#    w = crop_w.to_s
#    h = crop_h.to_s
#      
#    size = w << 'x' << h
#    offset = '+' << x << '+' << y
#    
#    
#	  crop_size_offset = "#{size}#{offset}"
#	end
	

	def titleize_name
		self.title[0]= self.title[0].capitalize      unless self.title.blank?
	    self.forename[0]= self.forename[0].capitalize   unless self.forename.blank?
	    self.surname[0]= self.surname[0].capitalize   unless self.surname.blank?
	end

	def ensure_stage_name
		stage_name = []
		stage_name << title   unless    title.blank? 
		stage_name << forename  unless forename.blank?
		stage_name << surname unless surname.blank?
		self.stage_name = stage_name.join( " ")
	end


	def self.speakers_for_render_group_by_happening(recording_ids)
	   speakers_for_recordings(recording_ids).group_by{|s|s.speaker_happening_id}
	end


	#def process_avatar
	#	yield
	#	binary = self.photo.download
	#	
  #			self.avatar.attach(io: binary, file_name: "filename"
  #				)
 #
	#	
	#	logger.debug "\n\n need to process avatasr image\n\n"
	#	return true
	#end
private
    def verify_destroy
        allow_destroy=   true
  
        unless contributions.empty?           
           errors.add(:base, "This speaker has made contributions")
           allow_destroy=   false
       end
       
        (throw :abort )unless allow_destroy
    end

	def crop_avatar
   
	  avatar.recreate_versions! #if recreate.present?
    
	end
end
