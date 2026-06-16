class Assignment < ApplicationRecord
  # attr_accessor :skip_role_list_validation

 #######################################   callbacks  ################################
 # before_destroy :verify_destroy
 #######################################   associations  ################################

 belongs_to :role
 belongs_to :user
 belongs_to :centre , optional: :true

#######################################   validations  ################################
 validates_presence_of :role, :user
 #validates_presence_of :centre
 validates_uniqueness_of   :role_id, :scope => [:user_id,:centre_id], message: 'has already been assigned'
 validate :validate_role_list, unless:  Proc.new{ |assignment|  assignment.role_id ==9}  

# validate :brickwall
 #######################################   scopes  ################################

 scope :by_user,lambda{|user_id | where(:user_id =>user_id)}


 scope :plucked_by_centre, -> { joins(:user)
                               .group(["user_id,assignments.role_id,assignments.id"])
                               .pluck(Arel.sql("assignments.user_id, ARRAY[assignments.role_id, assignments.id]"))
   
 }
 

# using ArrayToHashes module
  def self.assignment_ids_with_role_id_by_user
     nested_array_to_nested_hash plucked_by_centre
  end
  
  def self.nested_array_to_nested_hash(nested_array)
    h = Hash.new{ |h,k| h[k]=[] }
    nested_array.each{ |k,v| h[k] << v }
    h.each { |k, v| h[k] = v.to_h } 
    return h
  end

  private
  


  #  only site user can create Centre user
  def validate_role_list
    role_array = Role.centre_roles.ids
 
    validates_inclusion_of :role_id, in:  role_array, message: "Please choose a valid role"
  end

  private

 def verify_destroy
   allow_destroy=    true
   
   
     errors.add(:base, " im a brick wall!!")
     allow_destroy= false 
   (throw :abort )unless allow_destroy
  end
  
  def brickwall
		self.errors.add(:base, "brick_wall!")
		return false
  end

end


