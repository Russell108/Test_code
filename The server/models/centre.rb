# things to do
# validation of centre_formats only if packages & resources empty
# check assignments deleted when centre destroyed


class Centre < ApplicationRecord
  #  create, update delete only by site admin
  #  when a centre format is archived/deleted delete default resources & packages for courses & happenings
#  include MemoryValidation
  include EmailValidatable
  strip_attributes :collapse_spaces => true
  
#  # broadcasts_to ->(bucket) { :buckets }
#  after_create_commit -> {broadcast_prepend_to :centres, partial: 'admin/centres/show'}
#  after_update_commit -> {broadcast_replace_to :centres, partial: 'admin/centres/show'}
#  after_destroy_commit -> {broadcast_remove_to :centres}
#  
  #######################################   callbacks  ################################
   
  before_destroy :verify_destroy


  has_many    :courses,->{ readonly(true)} 
   has_many :happenings , as: :happenable
  has_many    :events, as: :happenable
  has_many    :gatherings, as: :happenable
  has_many    :projects, as: :happenable  
  has_many    :assignments
  has_many    :users, :through => :assignments
  has_many    :admins, class_name: "User"
  has_many    :venues
  belongs_to  :bucket, ->{ readonly(true)}
  has_many    :centre_formats, :dependent=>:destroy
  has_many    :formats, through: :centre_formats, source: :format
  has_many    :current_centre_formats, -> { where("current = true")}, class_name: "CentreFormat"
  has_many    :current_formats, through: :current_centre_formats, source: :format
  accepts_nested_attributes_for :centre_formats , allow_destroy: true
  
  validates_presence_of :name,  :bucket,:sales_email
  validates :sales_email, :presence => true

  validates :sales_email, email: true
  validates_uniqueness_of :name

  #====================================   scopes   ===============================================

#    scope :by_admin_user,lambda{|user_id | where(:assignments=> {:user_id => user_id}).joins(:assignments)}



   private

  def verify_destroy
    allow_destroy=    true
    
    unless gatherings.empty?            
      errors.add(:gatherings,  "exist for this centre." )
      allow_destroy=    false
    end
    unless projects.empty?            
      errors.add(:gatherings,  "exist for this centre." )
      allow_destroy=    false
    end
    unless events.empty?            
       errors.add(:events,  "exist for this centre." )
       allow_destroy=    false
     end
     
     unless courses.empty?           
       errors.add(:courses,  "exist for this centre." )
       allow_destroy=    false
     end
     #   errors.add(:base, " im a brick wall!!")
     #   allow_destroy= false 
    (throw :abort )unless allow_destroy
   end


end