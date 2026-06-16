class Event < Happening
  include Lockable

  before_destroy :verify_destroy
  around_save :remove_invalidated_carts, :if => Proc.new { |event| event.sales_scope_id_changed? } 
  #====================================   relationships   ===============================================
 
   belongs_to :sales_scope,->{ readonly(true)}   
   
#====================================   Validations   ===============================================
  validates_presence_of :sales_scope , on: :create
  
  validates_uniqueness_of :title , scope: [:happenable_id, :happenable_type]
  validate    :validate_sales_scope
#====================================   scopes   ===============================================
    scope :with_resourse_format,lambda{|format_id | where("resources.format_id = ?", format_id).joins(:recordings=> :resources)}

    scope :for_admin , lambda{|user | 
      left_outer_joins(:protected_admins)
      .where("happenings.happenable_id=? and (happenings.protected = ? or protected_admins.user_id = ?)",
       user.centre_id,  false,  user.id).distinct
    }
    
    scope :for_uploader , lambda{|user | 
      where("happenings.happenable_id=? ", user.centre_id)
    }
    
    scope :for_acquire_administration, lambda{|user | 
      left_outer_joins( centre: {assignments: :role}).where("(centres.id=? and assignments.user_id =? and roles.name =? )",
        user.centre_id, user.id,   'Acquire').distinct
    } 
    
 


#====================================   Public Methods   ===============================================
  

  
  def group_for_user(user)
   attached_groups.find_by(user_id: user.id).group rescue nil
  end
   


   


 
#====================================   Private Methods   ===============================================

    private

    def remove_invalidated_carts
      yield
      
        carts.each do|cart|
            cart.destroy unless cart.valid?
        end
   
    end

    def validate_sales_scope
       errors.add(:sales_scope, "invalid Input") if (sales_scope_id ==2) 
    end
    
    
  
end