class Membership < ApplicationRecord
 
	around_destroy :remove_carts
	around_update :remove_carts, :if => Proc.new { |membership| membership.mbr_type_id_changed? and (membership.mbr_type_id ==1)} 
  #====================================   relationships   ===============================================

	belongs_to	:user
	belongs_to :joinable , polymorphic: true 
  belongs_to  :happening, -> { where( memberships: { joinable_type: 'Happening' } ).includes( :happenings ) }, foreign_key: 'joinable_id', required: false
  belongs_to  :course, -> { where( memberships: { joinable_type: 'Course' } ).includes( :courses ) }, foreign_key: 'joinable_id', required: false
  
  belongs_to :mbr_type
    
  has_many  :registrations, dependent: :destroy
  
  accepts_nested_attributes_for :registrations
	#====================================   validations   ===============================================

 #	validates_presence_of :happening
 	validates_presence_of :user
	#validates_uniqueness_of :user_id, scope: :happening_id,  message: "already a member."
  validates_uniqueness_of :user_id, scope:  [:joinable_type, :joinable_id],  message: "already a member."
 	validate :user_is_not_archived?
  validate :user_exists_in_database
 	#====================================   scope   ========================================================
 	scope :by_user,lambda{| user_id| where(:user_id =>user_id)}
#	scope :by_happening,lambda{| happening_id| where(:happening_id =>happening_id)}
#	scope :by_course,lambda{| course_id| where(:happenings =>{happenable_type: "Course", :happenable_id=> course_id}).joins(:happening)}
  scope :inactive, ->{  where(:active=> false)}
  scope :active, ->{  where.not(mbr_type_id: 1)}
 	scope :select_for_index, ->{ select("memberships.id, memberships.active, user_id,users.email, CONCAT_WS(' ', users.forename, users.surname) AS fullname,\
          users.archived,users.unconfirmed_email,users.confirmed_at").joins(:user)}
          
  scope :by_name_or_email,lambda{|name | joins(:user).where("forename ILIKE ? or surname ILIKE ? or email ILIKE ?",
                                               "%#{name}%","%#{name}%", "%#{name}%")}
  
  scope :by_name_or_email_split,lambda{|name_0, name_1 | joins(:user).where("(forename ILIKE ? or surname ILIKE ? or email ILIKE ?) and
  																(forename ILIKE ? or surname ILIKE ? or email ILIKE ?)", 
                                               "%#{name_0}%","%#{name_0}%", "%#{name_0}%","%#{name_1}%","%#{name_1}%", "%#{name_1}%")}
                                               
	#====================================   public methods   ===============================================
   
   
    def self.user_search_limit_search_to_2_strings(search_string= nil)
        string = search_string.blank? ? [] : search_string.split 
        case string.size
        when 0
          all
        when  1
           memberships = by_name_or_email(search_string.strip)
         else
           memberships = by_name_or_email_split(string[0], string[1])
        end
    end
    
    def self.manage_by_team_for_joinable(joinable,users, mbr_type_id)
      
      memberships= []
      users.each do |user|
        membership = joinable.memberships.find_or_initialize_by(user_id: user.id ) do |mship|
          mship.mbr_type_id = mbr_type_id 
        end
        memberships << membership
      end
     import_result=  Membership.import memberships ,validate: true, validate_uniqueness: true,  on_duplicate_key_ignore: true 
     logger.debug "\n\nimport_result in  self.manage_by_team_for_joinable #{import_result}\n\n"
      return results_array_from_import(users.size, import_result,  "#{joinable.class.name} membership could not be created")
    end
    
 

	#====================================   private methods   ===============================================
	private

  def self.results_array_from_import(group_users_size, import_result, start_message)
    import_size =import_result.ids.size
     errors=["<BR><u class='text-dark'>#{group_users_size- import_size} #{start_message}:</u>"]
    import_result.failed_instances.each do |instance| 
      instance.errors.full_messages.each do |message|
        errors |= [User.find(instance[:user_id]).fullname + " " + message  ]
      end
    end
    return[import_result.ids.size, errors]
  end
  
  def self.aad_flash_messages_for_existing_memberships
    
  end
 
 
	def user_is_not_archived?
   		errors.add(:user, "has been archived") if (user && user.archived)
	end
  
  def user_exists_in_database
    errors.add(:user, "doesn't exist") unless User.exists? user_id
  end

	def remove_carts
        yield
        
        if(joinable_type =="Course")
          happening_ids = joinable.happening_ids
			    Cart.by_user(user_id).where(happening_id: happening_ids).each do |cart|
                cart.destroy unless cart.valid?
            end
        else
			    joinable.carts.by_user(user_id).each do |cart|
                cart.destroy unless cart.valid?
            end
        end
	end

 
   
   def brickwall
 		self.errors.add(:base, "brick_wall!")
 		return false
   end

end

