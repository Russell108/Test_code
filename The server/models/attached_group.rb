class AttachedGroup < ApplicationRecord
  belongs_to :user
  belongs_to :group
  belongs_to :happening
  
	#====================================   validations   ===============================================


  validates_uniqueness_of :user_id, scope:  [:happening_id],  message: "already has attached group."

 
end
