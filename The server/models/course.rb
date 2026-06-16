class Course < ApplicationRecord
  include Joinable
  include Lockable
  strip_attributes :collapse_spaces => true
  
  
 # attribute :groupable, :boolean , default: false probably not used 11/2/2026
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
  before_destroy :verify_destroy
  around_update :remove_invalidated_course_carts, :if => Proc.new { |course| course.sales_scope_id_changed?} 
  
  after_initialize :init_defaults, if: :new_record?
  around_update  :create_protected_admin,  if: Proc.new { |course| course.protected_changed? and (course.protected == true)}
  around_create  :create_protected_admin,  if: Proc.new { |course| course.protected == true}
  #====================================   relationships   ===============================================


  belongs_to :talk_type, optional: true
  belongs_to :centre
 
 
  has_many :meets , as: :happenable
  has_many :happenings, as: :happenable
  has_many :orders, :through=> :meets
  has_many :recordings, :through=> :meets
  has_many :resources, :through=> :recordings
  has_many :customers, :through=> :meets
  belongs_to :sales_scope,->{ readonly(true)}  
  has_many :memberships, as: :joinable, dependent: :destroy
  has_many :users, through: :memberships
  has_many :protected_admins , as: :administerable
  
  has_many :default_bundles
  
  has_many :default_items , as: :defaultable
  
  has_many :default_resources , as: :defaultable
  has_many :default_resource_formats , through: :default_resources, source: :format
  
  has_many :default_prints , as: :defaultable
  has_many :default_print_formats , through: :default_prints, source: :format
  
  has_many :default_packages , as: :defaultable
  has_many :default_package_formats , through: :default_packages, source: :format
  
 
#====================================   Validations   ===============================================

 
 # validates_presence_of   :kind  ,  :if => Proc.new { |c| c.new_record?}, message: "Please select type of course meets"
  validates_presence_of   :title#,:sub_title
  validates_presence_of   :start_date,:end_date
  validates_presence_of   :centre
  
  validates_associated  :default_resources, message: "Some default resources are invalid"
  
  validates_uniqueness_of :title, :scope=> [:centre_id,:group], message: " has already been taken."
  validate    :ending_date,  :if => Proc.new { |c| !c.start_date.blank? && !c.end_date.blank?}
  validate :default_resources_valid, :default_packages_valid, :print_formats_availability
  validates :priority, numericality: { only_integer: true, in: 1..10 },allow_nil: true
#  validate :transcription_is_a_valid_status#, if: -> {priority.present? }
#  validate   :brick_wall
  #====================================   scopes   ===============================================

  scope :by_centre,lambda{|centre_id | where(:centre_id =>centre_id)}


  scope :for_admin , lambda{|user | left_outer_joins(:protected_admins)
    .where("courses.centre_id=? and (courses.protected = ? or protected_admins.user_id = ?)",
     user.centre_id,  false,  user.id).distinct
  }
  
  scope :for_transcription , lambda{|user | where("courses.centre_id=?", user.centre_id)
  }
  
  scope :for_acquire_administration, lambda{|user | 
    left_outer_joins( centre: {assignments: :role}).where("(centres.id=? and assignments.user_id =? and roles.name =? )",
      user.centre_id, user.id,   'Acquire').distinct
  } 
  
 
 

  #====================================   Public Methods   ===============================================
  def self.text_search(query)
   where("title ILIKE ? or title @@ ? ", query,query) 
  end


  def dates
    card_dates = start_date.strftime("%e/%m/%Y").to_s
    (card_dates << (" to: " + end_date.strftime("%e/%m/%Y").to_s) )if end_date
    return card_dates 
  end

  def course_meets_title
    card_title = "<H5>#{self.name} ".html_safe 
    card_title << start_date.strftime("%e/%m/%Y").to_s  
    (card_title << (" to: " + end_date.strftime("%e/%m/%Y").to_s + "</H5>").html_safe )if end_date  
    return card_title
  end

  def current_centre_format_ids
    CentreFormat.are_current.by_centre(self.centre_id).collect(&:format_id)
  end
  
  def add_recordings_to_transcription_service(course_params)
    self.assign_attributes(course_params)
 
  updated_recordings = 0
  happenings.each do |happening|
   updated_recordings += happening.add_recordings_to_transcription_service(course_params)
  end
    
    
  
    

               return updated_recordings
  end


  
  
  #====================================   Private Methods   ===============================================

  private
  
  def create_protected_admin
    logger.debug "\n\n add an admin\n\n"
    yield
    pa= self.protected_admins.find_or_create_by(user_id: current_user_id)
    
    logger.debug "\n\n add an admin #{pa.valid?} \n\n"
    logger.debug "\n\n add an admin #{pa.errors.full_messages} \n\n"
  end


  def init_defaults
    self.sales_scope_id= 1
  end
  
  def verify_destroy
    allow_destroy=   true
    unless meets.empty?           
        errors.add("Meets", " exist for this Course")
        allow_destroy=   false
    end
    (throw :abort )unless allow_destroy
  end






  def ending_date
    errors.add(:end_date, "must be greater than start date") if start_date >= end_date 
  end

  def default_resources_valid
      format_ids = Format.current_by_centre(centre_id).ids
      unless((default_resource_format_ids - format_ids).empty?)
          errors.add(:default_resource_format_ids, "Some formats not available for this centre") 
  
      end
  end

  def print_formats_availability
    # print format must be a default format
    format_ids = Format.current_by_centre(centre_id).is_purchasable.ids
    unless( (default_print_format_ids- format_ids).empty?)
        errors.add(:default_print_format_ids, "Some formats not available for this centre") 
    end
  end
  
  def default_packages_valid
      format_ids = Format.current_by_centre(centre_id).ids
      unless((default_package_format_ids - format_ids).empty?)
          errors.add(:default_package_format_ids, "Some formats not available for this centre") 
  
      end
  end


  def remove_invalidated_course_carts
  
    yield #saves
    # delete cart if user is not eligible 
    orders.where(type: "Cart").each do |cart|
        cart.destroy unless cart.valid?
    end
  
  end


  def brick_wall
  	errors.add(:base,"Russ Courses & co Brick Wall")
  		throw :abort
  end
  
end
