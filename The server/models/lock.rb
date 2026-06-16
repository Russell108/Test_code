class Lock < ApplicationRecord
  
  # callbacks
  around_create :lock_mmets_recordings_and_resources ,   if: Proc.new { |lock| (lock.lockable_type == "Course") }
  around_create :lock_recordings_and_resources ,   if: Proc.new { |lock| (lock.lockable_type == "Happening") }
  around_create :lock_resources ,   if: Proc.new { |lock| (lock.lockable_type == "Recording") }
  
  #====================================   Relationships   ==================================== 
  	belongs_to :lockable , polymorphic: true  
    belongs_to  :happening, -> { where( locks: { lockable_type: 'Happening' } ).includes( :locks ) }, foreign_key: 'lockable_id', required: false
    belongs_to  :recording, -> { where( locks: { lockable_type: 'Recording' } ).includes( :locks ) }, foreign_key: 'lockable_id', required: false
   # belongs_to :event, as: :lockable
   def lockable_type=(sType)
     super(sType.to_s.classify.constantize.base_class.to_s)
   end
   
   private
   
   def lock_mmets_recordings_and_resources
     logger.debug ""
     yield
     self.lockable.meets.each{|meet|  Lock.find_or_create_by(lockable: meet)}
     self.lockable.recordings.each{|recording|  Lock.find_or_create_by(lockable: recording)}
     self.lockable.resources.each{|resource|  Lock.find_or_create_by(lockable: resource)}
   end
   
   def lock_recordings_and_resources
     logger.debug ""
     yield
     self.lockable.recordings.each{|recording|  Lock.find_or_create_by(lockable: recording)}
     self.lockable.resources.each{|resource|  Lock.find_or_create_by(lockable: resource)}
   end
   
   def lock_resources
     logger.debug "\n\n lock_resources  #{self.lockable.resources.size}\n\n"
     yield
     self.lockable.resources.each{|resource|  Lock.find_or_create_by(lockable: resource)}
   end
end
