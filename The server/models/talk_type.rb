class TalkType < ApplicationRecord
  
  before_validation :titleize_name, :unless => Proc.new{ |talk_type|  talk_type.name.blank?  }
  before_destroy :verify_destroy
	has_many :users
  
  has_many :resources
	#has_many :memberships, class_name: "User"
	has_many :accesses, :inverse_of => :talk_type, dependent: :destroy
  has_many :parent_group_accesses , foreign_key: "access_type_id", class_name: "Access", dependent: :destroy
	has_many :family_groups, :through=> :accesses
	#u.accesseshas_many :family_groups, :through=> :family_group_accesses
  has_many :parent_groups,  :through=> :parent_group_accesses, source: 'talk_type' 


  validates_uniqueness_of :name, :case_sensitive => false
  validates_presence_of  :name
  
  
  private
  
  def titleize_name
     self.name= self.name.titleize
  end
  
  def verify_destroy
      allow_destroy=   true
  
      unless users.empty?           
         errors.add(:base, "Members exist please reallcate")
         allow_destroy=   false
      end
      
      unless resources.empty?           
         errors.add(:base, "resources allocated to the group please reallcate")
         allow_destroy=   false
      end
      
     
    #  errors.add(:base, "brick wall")
    #  allow_destroy=   false
      (throw :abort )unless allow_destroy
  end
end
