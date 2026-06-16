class User < ApplicationRecord
		
	class AccessUnauthorised < StandardError; end
	# 	when user archived delete associations
	# 	cannot archive a user if they are manager of area
	# 	lapse memberships
	#  validate on update if available_workcentres empty then centre_id nil

  # Include default devise modules. Others available are:
  #  , :validatable:rememberable,  :timeoutable and :omniauthable
   devise :database_authenticatable, :registerable,:lockable, :timeoutable,
         :recoverable, :trackable, :confirmable
	attr_accessor :send_email , :current_password
    attribute :current_admin_centre
    attribute :post_token
	#attribute :colour, :string

	# enable logging with paper trail gem
	strip_attributes :collapse_spaces => true
	
	#after_save  :archive_associations,    :if => Proc.new{ |u|  u.archived }
	before_destroy :verify_destroy 
	before_validation :titleize_name, :unless => Proc.new{ |u|  u.surname.blank? or u.forename.blank? }
	before_validation :downcase_email, :unless => Proc.new{ |u|  u.email.blank?  }
  before_validation :nulify_empty_sponsor
	before_validation :generate_devise_confirmation_token, on: :create , :if => Proc.new{ |user| user.confirmation_token.blank?}
	
	around_save  :lapse_memberships, :if => Proc.new{ |user| user.archived_changed?  &&  (user.archived==true)}
	around_save :remove_associations, :if => Proc.new { |user| user.archived_changed?  &&  (user.archived==true)} 
#	around_save :update_moderateships, :if => Proc.new { |user| user.talk_type_id_changed? } 

#if user asks for password then replieds to email confirm the email
  around_update :confirm_account ,   if:  Proc.new{ |user| user.encrypted_password_changed? }
	#######################################   validations  ################################
	validates_uniqueness_of :email, allow_blank: true, allow_nil: true
	#validates_presence_of  :email
	validates_format_of :email, :with => /.+@.+\..+/i,  :if => Proc.new{ |user| !user.email.blank?}
	##validates_confirmation_of :password, :on=>:create
	validates_length_of :password, :within => Devise.password_length , :allow_blank => false,    :if => :password_validation_required?
	validates_confirmation_of :password
	validates_presence_of :forename, :surname, :confirmation_token, :email, message: "missing"
  validates_uniqueness_of :confirmation_token, message: "must be unique" , allow_blank: true, allow_nil: true
	validates_length_of  :forename, minimum: 2, too_short: 'please enter at least 2 characters', allow_blank: true, allow_nil: true
	
	validate :no_stupid_passwords ,    :if => :password_validation_required?
	validate :validate_centre , :if =>Proc.new{|user| user.centre_id_changed? && !user.centre_id.blank?}
	validate :email_against_unconfirmed_email
#######################################   associations ################################ns 
#	has_paper_trail ignore: [:failed_attempts, :sign_in_count, :current_sign_in_at, :last_sign_in_at]
	 # 10 mean you article will have 11 version include 'create' version
#  	PaperTrail.config.version_limit = 7
	
	
  

  has_many    :memberships,:inverse_of => :user,  dependent: :destroy
  accepts_nested_attributes_for :memberships
	has_many :attached_groups, dependent: :destroy
	has_many :assignments
  has_many :protected_admins, dependent: :destroy
	has_many :work_centres,->{distinct}, :through=>:assignments, source: :centre
	has_many :acquired_packages, dependent: :destroy
	has_many :packages, through: :acquired_packages
	has_many :acquired_resources,  dependent: :destroy
	has_many :resources, through: :acquired_resources
	has_many :orders
	has_many :carts, dependent: :destroy
	belongs_to	:centre, optional: true
	belongs_to :talk_type, optional: true
  has_many :family_groups, through: :talk_type
	belongs_to :sponsor, optional: true , class_name: "User"
  has_many  :beneficiaries, class_name: "User", foreign_key: "sponsor_id", dependent: :nullify
	has_many :recipientships
	has_many :family_digests, through: :recipientships
	has_many :group_memberships ,  dependent: :destroy
	has_many :groups, through: :group_memberships
#######################################   scopes  ################################

  scope :family, ->{  where("talk_type_id IS NOT Null and family_mailings IS true and archived is false")}
  scope :current, ->{  where(:archived=> false)}
  scope :archived ,->{ where(:archived=> true)}
  scope :by_name_or_email,lambda{|name | where("forename ILIKE ? or surname ILIKE ? or email ILIKE ?",
                                               "%#{name}%","%#{name}%", "%#{name}%")}
  
  scope :by_name_or_email_split,lambda{|name_0, name_1 | where("(forename ILIKE ? or surname ILIKE ? or email ILIKE ?) and
  																(forename ILIKE ? or surname ILIKE ? or email ILIKE ?)",
                                               "%#{name_0}%","%#{name_0}%", "%#{name_0}%","%#{name_1}%","%#{name_1}%", "%#{name_1}%")
  }
  

  
  scope :select_fullname, ->{ select("users.id, CONCAT_WS(' ', users.forename, users.surname) AS fullname")}
  
  scope :select_for_index, ->{ select("users.id,users.email,users.forename, users.surname, CONCAT_WS(' ', users.forename, users.surname) AS fullname,\
              users.archived,users.unconfirmed_email,users.confirmed_at")
  }
                    
	 # scope :to_redistribute, lambda{|family_digest_id | where("users.family_digest_id != ?",family_digest_id )}
	
  #find users who have acquired a package or resource for a happening
  scope :acquireships_for_happening,lambda{|happening_id |
    where("(packages.happening_id = ?) or (recordings.happening_id = ?)",happening_id,happening_id )   \
    .left_outer_joins({acquired_packages: :package},{acquired_resources: {resource: :recording}})
  }
   

   
  scope :with_centre_assignment,lambda{|centre_id | joins(:assignments)
    .where(assignments: {centre_id: centre_id}).distinct} 
  

                              
  scope :memberships_by_joinable_and_member_type ,lambda{|joinable_type, joinable_id, mbr_type_ids| joins(:memberships)
    .where("memberships.joinable_type =? and memberships.joinable_id =? and memberships.mbr_type_id in (?)", joinable_type,joinable_id, mbr_type_ids)
  }  
  
  scope :grouped_and_plucked_members_by_joinable ,lambda{|joinable_type, joinable_id| joins(memberships: :mbr_type)
    .where("memberships.joinable_type =? and memberships.joinable_id =?", joinable_type,joinable_id)
    .group("mbr_types.name")\
    .distinct\
    .pluck(Arel.sql("mbr_types.name, array_agg(users.forename::text || ' ' || users.surname::text)"))

  }  
    
  scope :registrations_by_meet_and_joinable_and_member_type ,lambda{| joinable_id,meet_id, mbr_type_ids| joins(memberships: :registrations)
    .where("memberships.joinable_type =? and memberships.joinable_id =? and memberships.mbr_type_id in (?) and\
    registrations.happening_id =?", 'Course',joinable_id, mbr_type_ids,meet_id)
  }                              
  
  scope :plucked_registerees_by_meet_and_team_and_grouped_by_member_type,lambda{|meet_id, membership_ids| joins(memberships: [:registrations, :mbr_type])
    .where("memberships.id in (?) and registrations.happening_id =?",membership_ids,meet_id)
    .group("mbr_types.name")\
    .distinct\
    .pluck(Arel.sql("mbr_types.name, array_agg(users.forename::text || ' ' || users.surname::text)"))
  }
  
  scope :user_ids_existing_registerees_by_meet,lambda{|meet_id| joins(memberships: :registrations)
    .where("registrations.happening_id =?",meet_id).ids
    
  }
  
  
  scope :pluck_for_speaker_render, lambda{ |user_ids|
      where(id: user_ids)
      .pluck(Arel.sql("users.id, ARRAY[ CONCAT_WS(' ', users.forename, users.surname),users.email::text,
        users.archived::text]"))
    }
	#====================================   Public Methods   ===============================================

  def current_administerable_happening_types
    happening_roles =[]
    course_roles=[]
    return [] if centre_id == nil
	  role_names= self.assignments.joins(:role)\
       .where("roles.name in (?) and centre_id =?",
         ["Public","Gathering","Project"], self.centre_id )
         .pluck("roles.name")
    happening_roles = [ 'Event']if role_names.include?("Public")
    course_roles = [ 'Meet']if role_names.include?("Public")
    happening_roles = happening_roles | (role_names - ["Public"])
    return [happening_roles,course_roles]
  end
  
  def self.user_search_limit_search_to_2_strings(search_string= nil)
      string = search_string.blank? ? [] : search_string.split 
      case string.size
      when 0
        all
      when  1
         users = by_name_or_email(search_string.strip)
       else
         users = by_name_or_email_split(string[0], string[1])
      end
  end
      # validate_centre_role_access
	def has_current_centre_assignment?(role_array)
    
		role_array =[role_array].flatten
		
      return false if centre_id == nil
		  self.assignments.joins(:role)\
         .where("roles.name in (?) and centre_id =?",
           role_array, self.centre_id ).any?
     
	end
  
  def is_active_site_admin?
    return false if self.centre_id.blank?
    assignments.where(centre_id: nil,  role_id: 1).any?
  end
  

  
  def has_key_holder_role_to_unlock_resource?(object_class_name)
    return false if centre_id.blank?
    self.assignments.joins(role: {key_holders: :model})\
        .where("models.name = ? and centre_id =?",
           object_class_name,  self.centre_id ).any? ||
    is_active_site_admin?
  end
  
	# used including for drop down to select centre
	def available_workcentres
		if self.is_active_site_admin?
			Centre.all 
		else
			work_centres
		end
	end
  

  def fullname
    forename + " " + surname
  end
  
	def plain_fullname
	  fore_name = forename || ''
	  sur_name = surname || ''
	  fullname= (fore_name.strip.capitalize + " " + sur_name.strip.capitalize)
	end

	#check if confirmation_token has not time expired  returns false if expired
	def confirmation_token_current?
    
	  User.confirm_within && self.confirmation_sent_at && (Time.now < self.confirmation_sent_at + User.confirm_within)
	end
	
	
	def confirmation_current?
	  return false if pending_reconfirmation?
	  return false unless confirmed?
	  return true
	end
	
	def update_admin_centre(params_user)
	#	unless valid_password?(params_user[:forename]) 
			errors.add(:password, "Password invalid")
			self.update_attributes(params_user)
	#	end
	end


	 # ensure user account is active  
	def active_for_authentication?  
    super && !archived 
	end  


	 # provide a custom message for a archived account   
	def inactive_message   
		!archived ? super : :archived_account 
	end  
  

  
  def valid_for_family_digest?
    (family_mailings &&  !archived && talk_type_id ) ? true : false
  end
  
  
  def validate_as_admin_customer(happening)
    
    eligible_customer=true
    if(self.archived)
      message = "has been archived".html_safe
      eligible_customer = false
    elsif(happening.type == "Meet")
      case happening.course.sales_scope_id
          when 1 #"All Affiliates"
            unless( happening.course.memberships.active.where(user_id: self.id).any?)
              eligible_customer = false
              message="Course membership required for purchase"
            end
          when 2 #Meet membership"
            unless happening.course.memberships.active.where(user_id: self.id).any?
              eligible_customer = false
              message="Meet membership required for purchase" 
            end
          else  #"Anyone"
      end
    else
     
      if( happening.sales_scope_id == 1)
        unless happening.memberships.active.where(user_id: self.id).any?
          eligible_customer = false
          message="Event Membership required for purchase" 
        end
      end
    end
    result = [eligible_customer, message]
    
    return result
  end
  
	def confirmation_token_current?
	  User.confirm_within && self.confirmation_sent_at && (Time.now < self.confirmation_sent_at + User.confirm_within)
	end


	#====================================   Private Methods   ===============================================

	private
	
	def brick_wall				
		self.errors.add(:base, "brickwall in  order")
		return false
	end	
	
	def password_validation_required?
	   password != nil
	end
  
  def no_stupid_passwords
    #  allowed=true
	      
    ( return false)if (forename.blank? || surname.blank?)
    if ((self.password.downcase.strip.include? self.forename.downcase) || (self.password.strip.downcase.include? self.surname.downcase))
      errors.add(:password, "You cannot use your forename or surname sequentially in your password.") 
	    
    end
	
    if (self.password.downcase.strip.include? self.email.downcase)
        errors.add(:password,"You cnnot use your email sequentially in your password.")  
       
    end
	      
  # BannedPassword.all.collect(&:name).each do |banned|
  #   if ((self.password.strip.include? banned) )
  #     errors.add(:password, "As it stands your chosen password  is considered insecure ==>\"#{banned}\" <==. 
  #      <BR>Please adapt your password or choose another. For example: use a number 0 instead of a letter O. <BR>Thank you!!".html_safe )
  #   
  #         throw(:abort)
  #   end
  # end
  end
	
  def titleize_name
    self.forename= self.forename.titleize
    self.surname= self.surname.titleize
  end

  def downcase_email
  	self.email.downcase!
  end


	
  def verify_destroy
    allow_destroy = true

    unless acquired_packages.where.not(order_id: nil).empty?    
      errors.add("Packages",  " have been purchased." )
      allow_destroy=   false
    end
		
    unless acquired_resources.where.not(order_id: nil).empty?           
      errors.add("Resource",  " have been purchased." )
      allow_destroy=   false
    end
    
		unless assignments.empty?           
		  errors.add(:assignments,  " Administration roles exist." )
		  allow_destroy=    false
		end
 #   errors.add(:base,  " brick wall." )
 #   allow_destroy=    false
    (throw :abort )unless allow_destroy
  end
	
  def lapse_memberships
  	yield
    logger.debug "\n\nlapse_memberships\n\n"
    memberships.update_all mbr_type_id: 1
    carts.destroy_all
  end

  def remove_associations
    #	self.forename = self.forename + " abc" 
  	yield
  	#self.associations.clear
    self.group_memberships.delete_all
  end

	  # valiation when changing admin centre 

 # def update_moderateships
 #   yield
 #   moderateable_talk_type_ids = self.talk_type.family_group_ids rescue nil
 #   moderateships = self.moderateships.where(moderateable_type: "TalkType").where.not( moderateable_id: moderateable_talk_type_ids).delete_all
 # 
 # end

	 def validate_centre
	 	unless  ((self.is_active_site_admin?) ||  (self.work_centre_ids.include? self.centre_id) )
	 		errors.add(:centre_id, "You don't have admin access to this centre!")
			  
	 	end
	 end

	 def email_against_unconfirmed_email 
     if self.new_record?
 	    if User.where("unconfirmed_email = ?",self.email).any?
 	    	errors.add(:email, "email already taken though as yet unconfirmed!!!")
 	    end
     else
	 	    if User.where("unconfirmed_email = ? and id !=?",self.email, self.id).any?
	 	    	errors.add(:email, "email already taken though as yet unconfirmed!!!")
	 	    end
      end
	 end
   
   def nulify_empty_sponsor
     if(( self.sponsor_id == 0 ) || (self.sponsor_id== "null") )
       self.sponsor_id =nil
       self.sponsor_notes =""
     end
    # logger.debug "\n\nuser #{self.inspect}\n\n"
   end

   def generate_devise_confirmation_token
   
       self.confirmation_token  = Devise.friendly_token
       self.confirmation_sent_at = Time.now.utc
   
   end
   
 
   
   def confirm_account
     
     yield
     confirm unless confirmed?
    # logger.debug "\n\nconfirm account\n\n"
   end
   
   # devise emails send using active queue
   def send_devise_notification(notification, *args)
     devise_mailer.send(notification, self, *args).deliver_later(queue: 'mailers')
     #     devise_mailer.send(notification, self, *args).deliver_later(wait: 60.seconds, queue: 'mailers')

   end
   

end
