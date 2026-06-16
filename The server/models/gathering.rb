class Gathering < Happening
   include Lockable

  before_destroy :verify_destroy
  #====================================   relationships   ===============================================
  

  belongs_to :sales_scope,->{ readonly(true)} 

  #====================================   Validations   ===============================================

  validates_uniqueness_of :title , scope: [:happenable_id, :happenable_type]

  #====================================   scopes   ===============================================
    #  scope :with_resourse_format,lambda{|format_id | where("resources.format_id = ?", format_id).joins(:recordings=> :resources)}

    scope :for_admin , lambda{|user | 
      left_outer_joins(:protected_admins)
      .where("happenings.happenable_id=? and (happenings.protected = ? or protected_admins.user_id = ?)",
       user.centre_id,  false,  user.id).distinct
    }
    
    scope :for_transcription, ->(user) {
      where(
        "(happenings.happenable_id = :centre_id AND happenings.type != :meet_type)",
        centre_id: user.centre_id,
        meet_type: 'Meet'
      )
    }
 
  #====================================   Public Methods   ===============================================

  def centre
      self.happenable
  end 
  

  
  #====================================   Private Methods   ===============================================

  private
end
  

