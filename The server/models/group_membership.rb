class GroupMembership < ApplicationRecord
  attribute :remove_emails, :string
  strip_attributes
  #====================================   Validations   ==================================== 
  validates_presence_of :user_id, :group_id
  validates_uniqueness_of :group_id, scope: :user_id, message: " user is already a mamber"
  
  #====================================   Relationships   ==================================== 
  
  belongs_to :group
  belongs_to :user
  validate :user_is_not_archived?
 
  #====================================   Scopes   ==================================== 


 	scope :by_user,lambda{| user_id| where(:user_id =>user_id)}
 	

#====================================   Public Methods   ===============================================

	#====================================   Private Methods   ===============================================
  
  private
  
	def user_is_not_archived?
   		errors.add(:user, "has been archived") if (user && user.archived)
	end
  

end
