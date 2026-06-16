class Country < ApplicationRecord
  
  # broadcasts_to ->(bucket) { :countries }
 # after_create_commit -> {broadcast_prepend_to :countries}
 # after_update_commit -> {broadcast_replace_to :countries}
 # after_destroy_commit -> {broadcast_remove_to :countries}
  ##############################  associations ###############################
  
  has_many :venues
  ##############################  validation ###############################
  validates_presence_of    :name 
  validates_uniqueness_of  :name
  
  before_destroy  :verify_destroy
  before_validation :titleize_name, :unless => Proc.new{ |country|  country.name.blank?  }
  private
  
  def verify_destroy
    allow_destroy =true
    unless   self.venues.empty?       
        errors.add("Venues", " exist for this country")
        allow_destroy=   false
    end
       (throw :abort )unless allow_destroy
  end
  
  def titleize_name
    self.name= self.name.titleize
  end
  
end
