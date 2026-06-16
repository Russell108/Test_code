class Meet < Happening
	attribute :meet_number, :integer
	attribute :set, :string
	attribute :default_bundle_ids , :integer, array: true
  
  accepts_nested_attributes_for :bundles
#===================   associations   ===================================
  belongs_to :course, -> { where( happenings: { happenable_type: 'Course' } ).includes( :happenings ) }, foreign_key: 'happenable_id', required: false
 
#===================  callbacks     ===================================	
 #before_validation :manage_course_visit_on_create , on: :create, :if => Proc.new { |meet| !meet.happenable.blank? }
 #before_validation :manage_course_visit_on_update , on: :update , :if => Proc.new { |meet|(( meet.course.sets == true) && meet.course_visit_changed?)}
  
  after_create :create_bundles
  after_initialize :default_meet_title, :if => Proc.new { |meet| meet.title.blank? }

#===================   validations   ===================================

#	validates_presence_of :meet_number   , on: :create
	
	validates_uniqueness_of :title, :scope=> :happenable_id, message: "already exists"
	validate :starting_date, :if => Proc.new { |meet| !meet.happenable.blank? }
  validate :ending_date, :if => Proc.new { |meet| (!meet.end_date.blank? && !meet.happenable.blank? )}
	

  #===================   scopes  ===================================
  	scope :by_course_centre,lambda{|centre_id | where("courses.centre_id=?", centre_id).joins(:course)}
    
    

    
    scope :for_acquire_administration, lambda{|user | 
      left_outer_joins({course: {centre: {assignments: :role}}}).where("(centres.id=? and assignments.user_id =? and roles.name =? )",
        user.centre_id, user.id,   'Acquire').distinct
    } 
    
 
  #===================   public methods   ===================================
  
  def customer_group
    case course.sales_scope_id 
      when 1
        message = "requires Course membership"
      when 2
        message = "requires Meet registration"
      else
        message ="available to all"
    end
    return message
  end
 
  def course_has_sets?
  	return self.happenable.sets
  end

  def set
  	
  	@set=""
  	if course_visit
  		meet_number = course_visit.to_i
  		if(meet_number.to_s != course_visit)
  			@set=course_visit[-1,1]
  		end
  	end
  end
  
  def sales_scope
    course.sales_scope
  end
  
  def set=(_set)
  		self.course_visit = self.course_visit.to_i.to_s + _set
  end
  
  def users_4_team_import(team2import, group =nil)
      split_string = team2import.split(' ')
     if (split_string[1] == "Course")
         team2import = "" unless (happenable_type=="Course")
     end
      case team2import
           when "customers"      
               users =( self.customers.group("users.id").order(Arel.sql("users.surname ")))
           when "group"
               users = User.joins(:group_memberships).where("group_memberships.group_id =?", group.id)
           when "All"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [1,2,3,4])
           when "Current"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [2,3,4])
           when "Student"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [2])
           when "Tutor"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [3])
           when "Guest"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [4])
           when "Lapsed"
               users = User.registrations_by_meet_and_joinable_and_member_type(happenable_id, id, [1])
          when "All Course"
              users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [1,2,3,4])
          when "Current Course"
              users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [2,3,4])
          when "Student Course"
              users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [2])
          when "Tutor Course"
              users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [3])
          when "Guest Course"
             users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [4])
          when "Lapsed Course"
              users = User.memberships_by_joinable_and_member_type('Course',happenable_id, [1])
          else 
              users= User.where('false')
      end
     return users
  end

 

 
  # this is what we are working on now
  def process_team_registration( team2import, mbr_type_id, group=nil)
    flash_error= ""
     flash_notice= ""
     if mbr_type_id.blank?
       flash_error << "Please choose a course membership type for registration" 
       return [flash_notice, flash_error]
     end
    unless (( (team2import =='group') and( !mbr_type_id.blank?)) ||
       ( (team2import !='group')and( !mbr_type_id.blank?) and (team2import.split(" ")[0] == MbrType.find(mbr_type_id).name) ))
      flash_error << "sorry soemthing went wrong" 
      return [flash_notice, flash_error]
    end
    
    processed_memberships_results = team_membership_ids_requiring_registration( team2import, mbr_type_id, group)
    unless processed_memberships_results[1].blank?
      flash_error << processed_memberships_results[1] << "<BR>"
    end
    team_current_memberships_ids = processed_memberships_results[0]
    ##################### we are here ####################
    existing_registerees  = Registration.plucked_by_meet_and_team_and_grouped_by_member_type( self.id, team_current_memberships_ids)
    registration_results= register_the_team(team_current_memberships_ids , mbr_type_id)
    flash_notice <<"#{registration_results[0]} #{"registrations".pluralize(registration_results[0]) } created<BR><BR>"
    flash_notice << registration_results[0]
    flash_error << registration_results[1].join("<BR>")
   
    messages_for_flash = add_existing_registrations_2_flash(existing_registerees)
    flash_notice << messages_for_flash[0] unless messages_for_flash[0].blank?
    flash_error << messages_for_flash[1] unless messages_for_flash[1].blank?
   
    
    return [flash_notice, flash_error]
  end
  
  def team_membership_ids_requiring_registration( team2import, mbr_type_id, group=nil )
     flash_error =''
    members_user_ids=[]
    if (team2import == "group")
      flash_error =   process_team_ensuring_course_membership(group, mbr_type_id)
      membership_ids= self.course.memberships.joins(user: :groups)
      .where("groups.id = ? ", group.id).ids
    else
     membership_ids = self.course.memberships.where(mbr_type_id: mbr_type_id).ids
    end
    return [membership_ids,flash_error]
  end
  
  def process_team_ensuring_course_membership(group, mbr_type_id)
    memberships=[]
    group.users.each do |user|
      membership = self.course.memberships.find_or_initialize_by(user_id: user.id ) do |mship|
        mship.mbr_type_id = mbr_type_id 
      end
      memberships << membership unless membership.persisted?
    end
   import_result=  Membership.import memberships ,validate: true, validate_uniqueness: true,  on_duplicate_key_ignore: true 
    
    error_messages_4_process_group_users_4_team_registration(memberships.size, import_result, "Course membership could not be created" )
  end
  
  def get_membership_ids_4_team_registration(team2import, mbr_type_id)
    case team2import
      when "Student Course"
          memberships = self.course.memberships.where("memberships.mbr_type_id=?",2)
      when "Tutor Course"
          memberships = self.course.memberships.where("memberships.mbr_type_id=?",3)
      when "Guest Course"
         memberships = self.course.memberships.where("memberships.mbr_type_id=?",4)
      else 
          memberships= {}
    end
    return memberships.ids
  end
  
  def register_the_team(current_memberships_ids , mbr_type_id)
   
    registrations =[]
    # find existing registrations add to flash by mbr_type_id
    
    team_course_membership_ids_on_the_register = self.registrations.where(membership_id:current_memberships_ids ).ids
    logger.debug "\n\nteam_course_membership_ids_on_the_register #{team_course_membership_ids_on_the_register}\n\n"
    team_course_membership_ids_requiring_registration = current_memberships_ids - team_course_membership_ids_on_the_register
    logger.debug "\n\nteam_course_membership_ids_requiring_registration #{team_course_membership_ids_requiring_registration}\n\n"
    team_course_membership_ids_requiring_registration.each do |id|
      registration = Registration.find_or_initialize_by(happening_id: self.id,membership_id: id  ) do |reg|
        reg.mbr_type_id = mbr_type_id
      end
  #    logger.debug "\n\nregistration #{registration.inspect}\n\n"
      registrations << registration unless registration.persisted?
    end
   #import_result=  Registration.import registrations ,validate: true, validate_uniqueness: true,  on_duplicate_key_ignore: true 
   columns = [:happening_id ,:membership_id] 
  import_result=  Registration.import columns,  registrations ,validate: true, validate_uniqueness: true , on_duplicate_key_ignore: true
   logger.debug "\n\nimport_result in  self.manage_by_team_for_joinable #{import_result}\n\n"
    return results_array_from_import(registrations.size, import_result,  "Errors on registration")
    
 #  # flash_notice ="#{results_array_from_import[0]} #{"registrations".pluralize(results_array_from_import[0]) } created<BR><BR>"
 #   flash_notice << "<u class='text-dark'>Active memberships already existing</u><BR>" 
 #   logger.debug "\n\nresult_for_flash #{result_for_flash}\n\n"
 #   logger.debug "\n\nflash_notice #{flash_notice}\n\n"
 #   flash_notice << result_for_flash[0]
 #   flash_error << result_for_flash[1]
 #   return  [flash_notice, flash_error]
  end
  
  def centre
  	happenable.centre
  end
  
  
  def valid_customer_user_ids(user_ids)
    logger.debug "\n\n meet valid_customer_user_ids(user_ids) #{user_ids}\n\n"
     logger.debug "\n\n sales scope #{course.sales_scope_id }\n\n"
    case course.sales_scope_id 
      when 1  # course members
        user_ids = course.memberships.joins(:user).where.not(mbr_type_id: 1)
        .where("memberships.user_id in (?) and users.archived = ?", user_ids, false ).collect(&:user_id)
      when 2   # meet registrations
       user_ids = registrations.joins(membership: :user).where.not(memberships: {mbr_type_id: 1})
       .where("memberships.user_id in (?) and users.archived = ?", user_ids, false ).collect{|reg| reg.membership.user_id}
      else
      user_ids= User.where(id: user_ids, archived: false).ids
    end
    return user_ids
  end

  def group_for_user(user)
   course.attached_groups.find_by(user_id: user.id).group rescue nil
  end
  
  def attached_group_for_user(user)
   course.attached_groups.find_by(user_id: user.id) rescue nil
  end 
  
#===================   private methods   ===================================
	
  private
  
  def add_existing_registrations_2_flash(registrations )
    flash_error=""
    flash_notice= ""
     flash_notice="<u class='text-dark'>Registrations already existing</u><BR>"
    registrations.each do |item|
      if item[0]== 'Lapsed'
        flash_error << "<u class='text-dark'>#{item[1].size} #{"Lapsed registration".pluralize(item[1].size)} already existing</u><BR>"
        flash_error << item[1].join(', ') + '<BR>'
      else
       flash_notice << item[0] + ' ' + item[1].size.to_s + '<BR>'
      end
    end
    return [flash_notice, flash_error]
  end
  


  def default_meet_title
   title= self.happenable.title 
   title << ( ' ' + self.happenable.sub_title ) if self.happenable.sub_title 
   title <<  " " + (self.happenable.meets.size + 1).to_s 
   self.title = title
  end

	def starting_date
		if start_date
			errors.add(:start_date, "is before Course dates") if( happenable.start_date > start_date )

			errors.add(:start_date, "is after Course dates") if( happenable.end_date && (happenable.end_date < start_date) )
		end
	end

	def ending_date
		if end_date
		errors.add(:end_date, "must be greater than Meet start date") if( start_date > end_date )
		errors.add(:end_date, "must be within Course dates") if(happenable.end_date &&( happenable.end_date < end_date) )
		end
	end
  
  def create_bundles
    return  unless default_bundle_ids
     default_bundle_ids=  self.default_bundle_ids.delete_if(&:blank?)
     unless default_bundle_ids.empty?
       default_bundles = self.course.default_bundles.where(id: default_bundle_ids ).includes(:default_items)
       default_bundles.each do |default_bundle|
        bundle = self.bundles.new(name: default_bundle.name,price: default_bundle.price ) 
        build_bundle_items(bundle, default_bundle.default_items.collect(&:format_id))
        bundle.save
        end
     end
  end
  
  def build_bundle_items(bundle, format_ids)
    format_ids.each do |format_id|
      package = self.packages.find_or_create_by(format_id: format_id)
      bundle.bundle_items.new(bundleable_type:'Package', bundleable_id:package.id )
    end
  end
  
  def error_messages_4_process_group_users_4_team_registration (group_users_size, import_result, start_message)
    import_size =import_result.ids.size
     errors=["<u class='text-dark'>#{import_result.failed_instances.size} #{start_message}:</u>"]
    import_result.failed_instances.each do |instance| 
      instance.errors.full_messages.each do |message|
        errors |= [User.find(instance[:user_id]).fullname + " " + message  ]
      end
    end
    return errors.join("<BR>").html_safe
  end
  
  def registrations_results_array_from_import_with_pre_imports(group_users_size, import_result, *pre_import_results, start_message)
    import_size =import_result.ids.size
    errors=["<u class='text-dark'>#{group_users_size- import_size} #{start_message}:</u><BR>"]
    pre_import_results.each do |import_result|
      import_result.failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
         # errors |= [message] unless(message =="Membership already registered.  ")
        end
      end
      
    end
    import_result.failed_instances.each do |instance| 
      instance.errors.full_messages.each do |message|
        logger.debug "\n\nmessage #{message}\n\n"
        errors |= [message] unless(message =="Email has already been taken")
      end
    end
    errors ="" if (errors.size ==1)
    
    return[import_result.ids.size, errors]
  end
  
end

