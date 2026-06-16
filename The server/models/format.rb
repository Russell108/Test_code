class Format < ApplicationRecord


#######################################  associations  #######################################

	has_many :resources, :inverse_of => :format
	has_many :packages, :inverse_of => :format
  has_many :acquired_packages, through: :packages
  has_many :bundle_items, through: :packages
	has_many :centre_formats
	has_many :default_items,dependent: :destroy
  has_many :allowed_extensions
  has_many :extensions, through: :allowed_extensions
#######################################  validations  #######################################
  validates_presence_of :name
  validates_uniqueness_of :name
  
  before_destroy :verify_destroy
#######################################  scopes  #######################################
	scope :is_packageable,->{  where(packageable: true)}
 	scope :is_downloadable,->{  where(downloadable: true)}
  scope :is_purchasable,->{  where(purchasable: true)}

  scope  :current_by_centre, lambda { |centre_id| 
    where("centre_formats.centre_id =? and centre_formats.current=true ",centre_id).joins(:centre_formats)}


 	

#######################################  private methods  #######################################
  private
  
  def some_method
    logger.debug "something happened here"
  end
  
	def  verify_destroy
		allow_destroy=   true
  
    
		unless (packages.empty?)
		    errors.add(:base, "packages exist for this format")
        allow_destroy=   false
    end
    
		unless (centre_formats.empty?)
		    errors.add(:base, "centre_formats exist for this format")
        allow_destroy=   false
    end
    
		unless (resources.empty?)
		    errors.add(:base, "Resources exist for this format")
        allow_destroy=   false
    end
    #errors.add(:base, " brickwall")
    #allow_destroy= false
		(throw :abort )unless allow_destroy
	end

end


