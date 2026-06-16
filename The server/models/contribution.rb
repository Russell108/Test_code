class Contribution < ApplicationRecord
  belongs_to :recording
  belongs_to :speaker
 
  
  validate :ensure_unlocked
  before_destroy :ensure_unlocked
  
#######################################   scopes  ################################

  scope :recording_peo,lambda{|recording_id,main |where(["main = ? and recording_id = ?",
                                main, recording_id ])}
  
 


#######################################   validations  ################################
  
  validates_presence_of :speaker_id, :recording_id
  validates_uniqueness_of :speaker_id, :scope => 'recording_id',
                            :message => "Is already a contributor for this recording!!"
 

               
#  def self.group_by_main(recording)
#    recording.contributions.find(:all,:include=>:speaker, :order=>"speakers.forename").group_by{|c|c.main}
#  end
        
  private
  
  def ensure_unlocked
    allow_update = true
   if recording.locked?           
    errors.add("recording",  " is locked. If you feel you need to edit please email your senior admin or support@drusound.com to discuss" )
    allow_update=   false
    
   end
   (throw :abort )unless allow_update
  end
 
end

