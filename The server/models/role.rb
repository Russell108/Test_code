class Role < ApplicationRecord


#######################################   associations  ################################
	has_many :assignments
 
	
#######################################   scopes  ################################
	
	scope :centre_roles,->{  where(centre_role: true)}
  scope :potential_addititional_keyholder_roles_roles,->{  where(name: ["Centre", "Warden"])}
  
  
  ###########################  Public Methods  ################################
  
 
#  def self.create_all_assignments(user, centre )
#    centre_roles.each do |role|
#        centre.assignments.create(user_id: user.id, role_id: role.id )
#    end    
#  end  
#  
#  def self.create_assignments(user, centre, roles=[])
#    centre_roles.each do |role|
#        centre.assignments.create(user_id: user.id, role_id: role.id ) if (roles.include? role.name)
#    end  
#  end
#  
#  def self.create_assignments_other_than(user, centre, roles=[])
#    centre_roles.each do |role|
#        centre.assignments.create(user_id: user.id, role_id: role.id ) unless (roles.include? role.name)
#    end  
#  end

end

