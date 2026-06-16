class Venue < ApplicationRecord
   strip_attributes :collapse_spaces => true
   include Lockable
  #====================================   Call backs   ==================================== 
       
  before_destroy :verify_destroy
  before_validation :titleize_name, :unless => Proc.new{ |v|  v.name.blank? }


  #===================   associations   ===================================
	has_many :happenings
	belongs_to :country
	#has_paper_trail 
	 # 10 mean you article will have 11 version include 'create' version
  #	PaperTrail.config.version_limit = 9
  #===================   validations   ===================================
  validates_uniqueness_of :name, :case_sensitive => false
  validates_presence_of  :name, :country_id

  #===================   scopes   ===================================

	scope :by_country,lambda{|country_id | where( country_id: country_id)}
 
 #===================   other   ===================================




#===================   private methods   ===================================
  private

  def editable_when_locked
    ['name']
  end
  
  def verify_destroy
      allow_destroy=   true
  
      unless happenings.empty?           
         errors.add(:base, "This venue is being used")
         allow_destroy=   false
      end
     # errors.add(:base, "bricked")
     # allow_destroy=   false
      (throw :abort )unless allow_destroy
  end
  
  def titleize_name
    self.name= self.name.titleize
  end
  
end
