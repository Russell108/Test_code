class Happening < ApplicationRecord
    include Joinable
    include Lockable
 
    include MemoryValidation
    strip_attributes :collapse_spaces => true
    
    attribute :current_user_id , :integer
    
    #============== virtual attributes for transcriptions ==============
    attribute :priority,:integer  # 1-10
    attribute :reset_failed_transcription, :boolean , default: false
    attribute :reset_pending_transcription, :boolean , default: false
    attribute :ignore_currently_requested_transcription, :boolean , default: false
  # enum :transcription_status, { 
  #   bypassed: 0, 
  #   pending: 1, 
  #   processing: 2, 
  #   completed: 3, 
  #   failed: 4,
  #.  encued: 5 
  # }
     #============== end virtual attributes for transcriptions ==============
    
    #====================================   Call backs   ==================================== 
       
  before_destroy :verify_destroy
  before_validation :nulify_empty_group
  around_update  :create_protected_admin,  if: Proc.new { |happening| happening.protected_changed? and (happening.protected == true)}
  around_create  :create_protected_admin,  if: Proc.new { |happening| happening.protected == true}
 
 before_save :sync_searchable_text, if: -> { title_changed? || body.changed? }
 
 
 
  after_initialize :initialize_defaults
  
  
  
    #====================================   Relationships   ==================================== 
  belongs_to  :venue
  belongs_to  :talk_type, optional: true
  belongs_to  :happenable , polymorphic: true    
  belongs_to  :centre, -> { where( happenings: { happenable_type: 'Centre' } ).includes( :happenings ) }, foreign_key: 'happenable_id', required: false
  belongs_to  :course, -> { where( happenings: { happenable_type: 'Course' } ).includes( :happenings ) }, foreign_key: 'happenable_id', required: false
  
  # has_many :memberships  from Joinable 
  has_rich_text :body
  # used to query the attached ActionText directly
   has_one :action_text_rich_text,
     class_name: 'ActionText::RichText',
     as: :record
  #has_many    :notices ,  dependent: :destroy
 	has_many    :recordings
 	has_many    :resources, through: :recordings
              
  has_many    :contributions, through: :recordings
  has_many    :speakers, through: :recordings
              
  has_many    :acquired_resources, through: :recordings 
  has_many    :cartable_resources, through: :recordings 
  has_many    :protected_admins , as: :administerable
  
 	has_many    :packages, :inverse_of => :happening
  has_many    :acquired_packages, through: :packages
              
  has_many    :acquirable_packages, -> { where("formats.acquirable = true").joins(:format)}, class_name: "Package"
 	has_many    :package_formats, :through => :packages, :source=> :format

 	has_many    :registrations, :inverse_of => :happening, dependent: :destroy
  has_many    :memberships, as: :joinable, dependent: :destroy
 	has_many    :orders
  has_many    :carts
  has_many    :processed_orders
  has_many    :customers, -> { where("type in (?)", ['Cart', 'ProcessedOrder'])},
               through:  :orders, source: "user"
  
  has_many    :bundles ,  dependent: :destroy
  
  has_many    :default_items , as: :defaultable
  has_many    :default_resources , as: :defaultable
  has_many    :default_resource_formats , through: :default_resources, source: :format
  
  has_many    :default_prints , as: :defaultable
  has_many    :default_print_formats , through: :default_prints, source: :format
              
  has_many    :default_packages , as: :defaultable
  has_many    :default_package_formats , through: :default_packages, source: :format
  has_many    :attached_groups
  has_one_attached :document
 #====================================   Validations   ==================================== 
  validates_presence_of :title 
  validates_presence_of  :start_date
  validates_length_of :title, maximum: 250
  validate    :ending_date
  validate :default_resources_valid, :print_formats_availability, :packages_valid, :if => Proc.new { |happening| !happening.happenable.blank? }
  validate :ensure_necessary_packages_are_not_deleted 
  validate :course_happenings_must_be_meets   , :if => Proc.new { |happening| (happening.happenable_type == "Course") || (happening.type == "Meet") }
   
#====================================   scopes   ==================================== 

  scope :by_family_genre,lambda{|genre_ids | where(["recordings.talk_type_id in (?)",genre_ids]).includes(:recordings)}
  scope :by_centre,lambda{|centre_id | where(:happenable_id =>centre_id, :happenable_type=>"Centre")}
  
  scope :for_acquire_admin, lambda{|user | 
    left_outer_joins( centre: {assignments: :role}).where("(centres.id=? and assignments.user_id =? and roles.name =? )",
      user.centre_id, user.id,   'Acquire').distinct
  }
  
  scope :with_acquisitions_for_user,lambda{|user_id | 
    where("acquired_packages.user_id = ? OR acquired_resources.user_id = ?", user_id, user_id)
    .left_outer_joins({packages: :acquired_packages}, {recordings:[{resources: :acquired_resources}, {contributions: :speaker}]})
  }
  
  scope :for_admin , lambda{|user | 
    left_outer_joins(:protected_admins, {course: :protected_admins})
    .where("happenings.happenable_id=? and happenings.type !=? ",
     user.centre_id, 'Meet').
     or(Happening.where("courses.centre_id=? and happenings.type =?",
     user.centre_id, 'Meet')).distinct
  }
    
  scope :for_transcription, ->(user) {
    joins(:course).where(
      "(happenings.happenable_id = :centre_id AND happenings.type != :meet_type) OR 
       (courses.centre_id = :centre_id AND happenings.type = :meet_type)",
      centre_id: user.centre_id,
      meet_type: 'Meet'
    )
  }
 
      

    
   #====================================   public methods   ==================================== 



    # Getter
     def family_access_id
       talk_type_id
     end
     
      # Setter
     def family_access_id=(talk_type_id)
       self.talk_type_id = talk_type_id
     end
    
  

    
    def self.select_options
        Happening.subclasses_of(self).map{ |c| c.to_s }.sort
    end

    def current_creatable_formats
        
        case type
           when "Meet"
               formats=  Format.current_by_centre(happenable.centre_id)
            else
               formats=  Format.current_by_centre(happenable.id)
        end
        return formats
       # Format.current_by_centre(current_user.centre_id)
    end

   


  
 
  def panel_title
    panel_title =  id.to_s + " " + title + "<BR>" + full_date
   
    return panel_title.html_safe
  end

  def full_date
     date = start_date.strftime("%e/%m/%Y")
     if end_date 
        date << " to "  + end_date.strftime("%e/%m/%Y")
      end
     return date
  end


  
  def dates_as_string
   dates =  start_date.strftime("%e/%m/%Y")
   if end_date 
      dates << " to " + end_date.strftime("%e/%m/%Y")
   end
   return dates
  end
  
  # please remove me
  
  def add_carts_to_group_import
    new_carts =[]
    group.users.current.each do |user|
      new_carts << self.carts.new(user_id: user.id)
    end
    import_result= Cart.import new_carts ,validate: true, validate_uniqueness: true
    return results_array_from_import(group.users.size, import_result," baskets were not added for one or more of the following reasons")
  end
  # please remove me
  def add_order_item_to_group_import_carts( order_item)
    order_items =[]
    
    group.users.current.each do |user|
      cart = self.carts.where(user_id: user.id).first
      order_items << OrderItem.new(order_id: (cart.id rescue nil),orderable_type: order_item[:orderable_type], orderable_id: order_item[:orderable_id] )
    end
    import_result= OrderItem.import order_items ,validate: true, validate_uniqueness: true
    return results_array_from_import(group.users.size, import_result," or more baskets  not updated due to one or more of the following reasons")
  end
  
  def add_order_item_to_team_import(team2import, order_item, group)
   # logger.debug "\n\n add_order_item_to_team_import\n\n"
    order_items =[]
    team_user_ids= users_4_team_import(team2import, group).ids
  #  logger.debug "\n\n team_user_ids #{team_user_ids}\n\n"
    team_user_ids_with_order_item = User.where(id: team_user_ids)
    .where(orders:{happening_id: self.id}).left_outer_joins(orders: :order_items)
    .where(orders:{ order_items:{orderable_type: order_item[:orderable_type], orderable_id: order_item[:orderable_id]}}).ids
    
    team_users_requiring_order_item =User.where(id:(team_user_ids-team_user_ids_with_order_item))
    
    pre_import_result = add_carts_to_team_import(team_users_requiring_order_item)
    
    import_result=  add_order_item_to_eligible_customers(team_users_requiring_order_item, order_item)
   # logger.debug "\n\nimport_result #{import_result.inspect}\n\n"
   
      remove_existing_carted_resources_available_through_bundle(team_users_requiring_order_item, order_item) if (order_item[:orderable_type] == "Bundle")

   
    #  find carts for team import that are empty and delete them
    carts = self.carts.left_outer_joins(:order_items).where(order_items: {id: nil}).where(user_id: team_user_ids).delete_all
    
    # falsh messages
  
    flash_notices_for_add_order_item_to_team_import(order_item[:orderable_type], pre_import_result, import_result, team_user_ids_with_order_item.size)
    
  end
  
  def add_carts_to_team_import(users)
    user_ids = users.ids
    user_ids_for_members_with_existing_cart= self.carts.where(user_id: user_ids).collect(&:user_id)
    new_carts =[]
    (user_ids- user_ids_for_members_with_existing_cart).each do |user_id|
      new_carts << self.carts.new(user_id: user_id)
    end
     import_result= Cart.import new_carts ,validate: true, validate_uniqueness: true
     return import_result
  end
  

  
  def create_or_update_memberships_for_team_import(team2import, membership_params)
    case type
    when "Event"
      create_or_update_event_memberships_for_team_import(team2import, membership_params)
    when "Meet"
      create_or_update_course_memberships_for_team_import(team2import, membership_params)
    end
  end

  
  def checkout_carts(orders)
    error_message=[]
    success_message=[]
    orders.in_groups_of( 50,false).each_with_index do |orders, index|
        
        orders.each_with_index do |order,ind|
              
             order.type = "ProcessedOrder"
            if  order.save
                order.user.update_attribute("confirmation_sent_at", Time.now)if (!order.user.confirmed? || order.user.pending_reconfirmation?)
                AdminSalesMailer.with(user_id: order.user_id,order_id: order.id).order_sales_email.deliver_later 
                #deliver_later(wait_until: (ind * 10).seconds.from_now)
                success_message <<  (order.user.forename + " " + order.user.surname)
            else
                error_message <<  (order.user.forename + " " + order.user.surname + ".  <BR>" +  order.errors.full_messages.join(", ") + "<BR>" )
            end
            
        end
    end
    
    items_deleted = self.remove_unnecessary_order_items(orders.collect(&:id)) unless error_message.empty?
    return [success_message,error_message]
  end
  
  
  def add_acquired_package_to_group_import_members(acquired_package, group)
    acquired_packages =[]
    format_id = Package.find(acquired_package[:package_id]).format_id
    group.users.current.each do |user|
      acquired_packages << AcquiredPackage.new(package_id: acquired_package[:package_id], user_id: user.id )
    end
    import_result= AcquiredPackage.import acquired_packages ,validate: true, validate_uniqueness: true
    users_who_acquired_ids = AcquiredPackage.where(id: import_result.ids).pluck("user_id")
    acquired_resources= self.acquired_resources.joins(:resource)
    .where(order_id: nil, user_id:users_who_acquired_ids, resources:{format_id:format_id }  )
    .delete_all
                       
                        
      
      return results_array_from_import(group.users.size, import_result," or more acquired packages  not added due to one or more of the following reasons")
      
  end
  
  def add_acquired_resource_to_group_import_members(acquired_resource, group)
    acquired_resources =[]
    group.users.current.each do |user|
      acquired_resources << AcquiredResource.new(resource_id: acquired_resource[:resource_id], user_id: user.id )
    end
    import_result= AcquiredResource.import acquired_resources ,validate: true, validate_uniqueness: true
    
    return results_array_from_import(group.users.size, import_result," or more acquired resources  not added due to one or more of the following reasons")
      
  end
  
  
  def remove_unnecessary_order_items(order_ids=nil)
    deletable_item_ids =[]
  # if use_group
  #   order_items =OrderItem.joins(order: {user: :group_memberships}).where("orders.type=? and orders.happening_id =?","Cart", id).where("group_memberships.group_id= ?", group_id)
  # else
      order_items = OrderItem.joins(:order).where(orders:{type: "Cart", happening_id: id})
#    end
    order_items.each do |order_item|
      deletable_item_ids << order_item.id if !order_item.valid?
    end
   
    OrderItem.where(id:deletable_item_ids).delete_all
    return  deletable_item_ids.any? 
  end
  
  def attached_group_for_user(user)
   attached_groups.find_by(user_id: user.id) rescue nil
  end 
  
  def initialize_defaults
    self.editable_when_locked = ["end_date","current_user_id"]
    self.sales_scope_id ||= 3
  end
  
  def users_4_team_import(team2import, group)
   
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
              users = User.memberships_by_joinable_and_member_type('Happening',id, [1,2,3,4])
          when "Current"
              users = User.memberships_by_joinable_and_member_type('Happening',id, [2,3,4])
          when "Student"
              users = User.memberships_by_joinable_and_member_type('Happening',id, [2])
          when "Tutor"
              users = User.memberships_by_joinable_and_member_type('Happening',id, [3])
          when "Guest"
              users = User.memberships_by_joinable_and_member_type('Happening',id, [4])
          when "Lapsed"
              users = User.memberships_by_joinable_and_member_type('Happening',id, [1])
          else 
              users= User.where('false')
      end
   #   logger.debug "\n\n users_4_team_import #{users.first.inspect}\n"
     return users
  end
  
  def valid_customer_user_ids(user_ids)
    case sales_scope_id 
      when 1  # event members
        user_ids = memberships.joins(:user).where.not(mbr_type_id: 1)
        .where("memberships.user_id in (?) and users.archived = ?", user_ids, false ).collect(&:user_id)
       else
      user_ids =memberships.joins(:user).where.not(mbr_type_id: 1).collect(&:user_id)
    end
    logger.debug "\n\nuser_ids #{user_ids}\n\n"
    return user_ids
  end

  
   def create_or_update_event_memberships_for_team_import(team2import, mbr_type_id)
     c_or_i_memberships= []
     users= users_4_team_import(team2import)
     users.each do |user|
       membership = self.memberships.find_or_initialize_by(user_id: user.id )
       membership.mbr_type_id = mbr_type_id unless( membership.mbr_type_id == 1)
       c_or_i_memberships << membership
     end
     import_result=  Membership.import c_or_i_memberships ,validate: true, validate_uniqueness: true,  on_duplicate_key_update: {conflict_target: [:id], columns: [:mbr_type_id]} 
     return results_array_from_import(users.size, import_result,  "  following reasons")
   end
   
   def customer_group
     message=
 		 case sales_scope_id
			when 1
				message="Mebership required"
 			when 2 
 				message="Mebership and registration required"
 			when 3 
 				message="All Admin allocated sales allowed"
 			when 4 
 				message="Public sales allowed"
 		end 
     return message
   end
   
   
   
   
   def add_recordings_to_transcription_service(course_params)
     logger.debug "\n\n :reset_pending_transcription #{course_params[:reset_pending_transcription].to_i == 1}\n\n"
  #   self.assign_attributes(course_params)
     if (course_params[:reset_pending_transcription].to_i == 1)
       logger.debug "\n\n reset_pending_transcription\n\n"
       priority =nil
       status=  "bypassed" 
   else
     logger.debug "\n\n do not set priority \n\n"
     priority=course_params[:priority]
     status= "requested" 
   end
    if (course_params[:reset_failed_transcription].to_i == 1)
      (statuses = ["failed"]) 
    else
      statuses = course_params[:ignore_currently_requested_transcription].to_i == 1 ? ["bypassed"] : ["bypassed","requested"]
    end
    logger.debug "\n\n  priority #{priority}\n\n"
     update_recordings=  recordings.by_transcription_status(statuses) 
                .update_all(priority: priority , transcription_status: status)
                 logger.debug "\n\n added #{update_recordings.size} recordings for transcription\n\n"
                 return update_recordings
   end
   
  
  #===============================================   private methods  =========================================================================

  private
  
  
  def sync_searchable_text
      self.searchable_text = "#{title} #{body.to_plain_text}"
    end
  
  
  def verify_destroy
    allow_destroy=   true
    
    unless packages.empty?           
         errors.add("Packages", " exist for this #{type}")
         allow_destroy=   false
    end
    
    unless recordings.empty?           
       errors.add("Recordings", " exist for this Event")
       allow_destroy=   false
    end
    (throw :abort )unless allow_destroy
  end
    
  def create_protected_admin
    yield
    pa= self.protected_admins.find_or_create_by(user_id: current_user_id)
    
  end

  
    def ending_date
     
      if end_date
      errors.add(:end_date, "must be greater than start date") if (start_date > end_date )
      end
      if end_date == start_date
        self.end_date = nil
      end
    end
    
    

    def default_resources_valid
        centre_id = (type == "Meet") ? happenable.centre_id : happenable_id
        format_ids = Format.current_by_centre(centre_id).ids
        
        unless((default_resource_format_ids - format_ids).empty?)
            errors.add(:default_resource_format_ids, "Some formats not available for this centre") 
            
        end
    end

    def print_formats_availability
      # print format must be a default format
      centre_id = (type == "Meet") ? happenable.centre_id : happenable_id
      format_ids = Format.current_by_centre(centre_id).is_purchasable.ids
      unless( (default_print_format_ids- format_ids).empty?)
          errors.add(:default_print_format_ids, "Some formats not available for this centre") 
      end
    end
  
    def packages_valid
        centre_id = (type == "Meet") ? happenable.centre_id : happenable_id
        format_ids = Format.current_by_centre(centre_id).is_packageable.ids
        unless((package_format_ids - format_ids).empty?)
            errors.add(:package_format_ids, "Some formats not available for this centre") 
  
        end
    end
    
    def course_happenings_must_be_meets
      if ((happenable_type == "Course")and (type != "Meet"))
       errors.add(:happenable, "Course Happenings must be meets")
     end
     if ((happenable_type == "Centre")and (type == "Meet"))
        errors.add(:happenable, "- Centre Happenings cannot be meets")
     end
    end
    
    def ensure_necessary_packages_are_not_deleted
      message = []
      packages_available = true
      bundle_items_package_ids =Package.joins(:bundle_items ).where('packages.happening_id =? and bundle_items.bundleable_type = ?',self.id, 'Package').ids.uniq
      proposed_package_ids = Package.where(happening_id: self.id, format_id: package_format_ids).ids
      required_package_ids_for_acquisitions = Package.joins(:acquired_packages).where("packages.happening_id =?", self.id ).ids
      unless (bundle_items_package_ids -proposed_package_ids).empty?
        packages_available =false
        message  <<   "bundle items"
      end
      unless(required_package_ids_for_acquisitions - proposed_package_ids).empty?
        packages_available =false
       message  <<  " acquired packages"
     end
     
        errors.add(:packages, ('missing for ' + message.join(' & '))) unless packages_available
    end
    
    def add_order_item_to_eligible_customers(team_users_requiring_order_item, order_item)
      order_items_2 =[]
      team_users_requiring_order_item.current.each do |user|
          cart = self.carts.where(user_id: user.id).first
          order_item_2 = OrderItem.new(order_id: (cart.id rescue nil),orderable_type: order_item[:orderable_type], orderable_id: order_item[:orderable_id] )
          logger.debug "\n\norder_item_2 vaild? #{order_item_2.valid?}\n\n"
           logger.debug "\n\norder_item_2 errors? #{order_item_2.errors.full_messages}\n\n"
          order_items_2 <<order_item_2
      end
   
     return  OrderItem.import order_items_2 ,validate: true, validate_uniqueness: true
    end
  
    def nulify_empty_group
    
     #  self.group_id =nil if(( self.group_id == 0 ) || (self.group_id== "null") )
     #  logger.debug "\n\ngroup #{self.inspect}\n\n"
    end
    
    def results_array_from_import(group_users_size, import_result, start_message)
      import_size =import_result.ids.size
       errors=["<BR><u class='text-dark'>#{group_users_size- import_size} #{start_message}:</u>"]
      import_result.failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
          errors |= [message]
        end
      end
      return[import_result.ids.size, errors]
    end
   
    def results_array_from_import_with_pre_imports_for_order_items(user_group_size, import_result, *pre_import_results, start_message)
      import_size =import_result.ids.size
      errors=["<u class='text-dark'>#{user_group_size- import_size} #{start_message}:</u><BR>"]
      pre_import_results.each do |import_result|
        import_result.failed_instances.each do |instance| 
          instance.errors.full_messages.each do |message|
            errors |= [message] unless(message =="User Cart already exists")
          end
        end
      
      end
      import_result.failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
          errors |= [message] unless(message =="Order user does not have cart")
        end
      end
      errors ="" if (errors.size ==1)
    
      return[import_result.ids.size, errors]
    end
   
    def flash_notices_for_add_order_item_to_team_import(order_item_type,pre_import_result, import_result, team_user_ids_with_order_item)
      
    #  logger.debug "\n\nflash_notices_for_add_order_item_to_team_import import_result #{import_result}\n\n"
      flash_notice= ""
      flash_error= ""
      
      flash_error << error_messages_for_pre_import(pre_import_result)
      flash_error << error_messages_for_import(import_result)
      if(import_result.ids.size >0)
        flash_notice << "order_item added for " +  import_result.ids.size.to_s + " #{"user".pluralize(import_result.ids.size)}"
      else
        flash_notice << "No #{order_item_type} added for any user"
      end
      if team_user_ids_with_order_item>0
        flash_notice << "<BR>#{order_item_type} already purchased or in cart for " + team_user_ids_with_order_item.to_s + " #{"user".pluralize(team_user_ids_with_order_item) }".html_safe
      end
      return [flash_notice,flash_error]
    end
    
    def error_messages_for_pre_import(pre_import_result)
       return '' if pre_import_result.failed_instances.empty?
      invalid_customers = pre_import_result.failed_instances.size
     
      flash_error= "#{invalid_customers} #{"user".pluralize(invalid_customers)} deemed an invalid customer<BR>"
      flash_error << combine_error_messages(pre_import_result.failed_instances)
    end
    
    def error_messages_for_import(import_result)
       return '' if import_result.failed_instances.empty?
      invalid_order_items = import_result.failed_instances.size
     
      flash_error= "#{invalid_order_items} #{"user".pluralize(invalid_order_items)} order items could not be added<BR>"
      flash_error << combine_error_messages_for_order_item(import_result.failed_instances)
    end
    
    def combine_error_messages(failed_instances)
      errors=[]
      failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
          errors |= [User.find(instance[:user_id]).fullname + " " + message  ]
        end
      end
      return (errors.join("<BR>") + "<BR><BR>").html_safe
    end
    
    def combine_error_messages_for_order_item(failed_instances)
      errors=[]
      failed_instances.each do |instance| 
        instance.errors.full_messages.each do |message|
          errors |= [User.find(instance.order[:user_id]).fullname + " " + message  ]
        end
      end
      return errors.join("<BR>").html_safe
    end
    
    def remove_existing_carted_resources_available_through_bundle(users, order_item)
      logger.debug "\n\nremove_existing_carted_resources_available_form_bundle \n\n"
      bundle = Bundle.find  order_item[:orderable_id]  #  bundle_packages  bundle=resources
      packaged_format_ids = bundle.packages.joins(:format).collect(&:format_id)
      #remove existing cart items which are  included in new bundle packages
      OrderItem.joins(:order, :resource).where("orders.type=? and orders.user_id in(?) and resources.format_id in (?)",
                'Cart', users.ids ,packaged_format_ids).delete_all
      #remove existing cart items which are  included in new bundle resources
      resource_ids= bundle.resources.ids
      OrderItem.joins(:order).where("orders.type=? and orders.user_id in(?) and order_items.orderable_type= ? and  order_items.orderable_id in (?)",
                'Cart', users.ids, 'Resource',resource_ids).delete_all
      #  
    end
end
