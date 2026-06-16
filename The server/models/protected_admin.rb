class ProtectedAdmin < ApplicationRecord
  belongs_to :user
  belongs_to :administerable, polymorphic: true
  
  belongs_to :course, foreign_key: :administerable_id, class_name: 'Course', optional: :true
  belongs_to :happening, foreign_key: :administerable_id, class_name: 'Happening', optional: :true
  
  before_destroy :ensure_one_admin_left
  
  #########################                  validation.   ########################################
  
 	validates_presence_of :administerable
 	validates_presence_of :user
	validates_uniqueness_of :user_id, scope: :administerable,  message: "%{value} already an admin."
 	validate :user_is_not_archived?
 # validate :brickwall
  private
  
  def user_is_not_archived?
   		errors.add(:user, "has been archived") if (user && user.archived)
  end
  
	def ensure_one_admin_left
		allow_destroy=   true
		if (administerable.protected and (administerable.protected_admins.size <= 1 ))     
		    errors.add("base", "Must be at least one Admin.")
		    allow_destroy=   false
		end
 #   errors.add(:base, " im a brick wall!!")
 #   allow_destroy= false 
		(throw :abort )unless allow_destroy
	end

  def brickwall
		self.errors.add(:base, "brick_wall!")
		return false
  end
  
end
