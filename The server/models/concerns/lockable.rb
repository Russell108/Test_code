#lib/extensions.rb

module Lockable
  extend ActiveSupport::Concern

  included do
    attribute :editable_when_locked, :string, array: true,default: []
    has_one :lock, as: :lockable, dependent: :destroy, autosave: true
    validate :ensure_unlocked, :if => Proc.new{ |lockable|  (lockable.locked? && !lockable.changed.empty?)  }
    before_destroy :ensure_unlocked_for_destroy
  end
  
  def locked?
    lock.present?
  end
  

    
  def security
   "enable locking"
  end
  
  private

  def ensure_unlocked
    return true unless locked?

    # 1. Define fields always permitted during a lock
    always_allowed = ["editable_when_locked", "current_user_id"]
  
    # 2. Combine with the model-specific allowed fields
    # Ensure we handle nil or string-array coercion safely
    allowed_fields = always_allowed + Array(editable_when_locked)

    # 3. Find if any changed fields are NOT in the allowed list
    unallowed_changes = self.changed - allowed_fields

    # 4. If there are unallowed changes, block the update
    if unallowed_changes.any?
      errors.add(:base, "#{self.class} is locked. If you feel you need to edit please email your senior admin or support@drusound.com to discuss")
      throw :abort
    end
  end
  
  def ensure_unlocked_for_destroy
    allow_update = true
   if locked?           
    errors.add("Lock",  "#{self.class} is locked. If you feel you need to edit please email your senior admin or support@drusound.com to discuss" )
    allow_update=   false
    
   end
   (throw :abort )unless allow_update
  end
  
 
end