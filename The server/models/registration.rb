class Registration < ApplicationRecord
  
  attribute :mbr_type_id, :integer
   attribute :user_id, :integer
  #====================================   relationships   ===============================================

  belongs_to :membership
  belongs_to :happening
  #====================================   validations   ===============================================
  validates_uniqueness_of :membership_id, scope: :happening_id,  message: ". This user is already registered."
  validate :user_is_not_archived?
  validate :membership_not_lapsed?
    
  #====================================   scopes   ===============================================
        # plucked_by_meet_and_team_and_grouped_by_member_type
  scope :plucked_by_meet_and_team_and_grouped_by_member_type,lambda{|meet_id, membership_ids| joins({membership: [:mbr_type, :user]})
    .where("memberships.id in (?) and registrations.happening_id =?",membership_ids,meet_id)
    .group("mbr_types.name")\
    .distinct\
    .pluck(Arel.sql("mbr_types.name, array_agg(users.forename::text || ' ' || users.surname::text)"))
  }
  
# scope :plucked_registerees_by_meet_and_team_and_grouped_by_member_type,lambda{|meet_id, membership_ids| joins(memberships: [:registrations, :mbr_type])
#   .where("memberships.id in (?) and registrations.happening_id =?",membership_ids,meet_id).distinct
#   .group("mbr_types.name")\
#   .pluck(Arel.sql("mbr_types.name, array_agg(users.forename::text || ' ' || users.surname::text)"))
# }
    
  private
    
	def user_is_not_archived?
   		errors.add(:user, "has been archived") if (membership && membership.user.archived)
	end
    
	def membership_not_lapsed?
   		errors.add(:membership, "lapsed for Course") if (membership && (membership.mbr_type_id == 1))
	end
 
end
