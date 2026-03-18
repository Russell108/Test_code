class Recording < ApplicationRecord
  
  has_one_attached :audio_file
  has_one_attached :raw_transcript, service: :raw_transcripts 
  #has_one_attached :raw_transcript, service: :dev_raw_transcripts 
  
  strip_attributes :collapse_spaces => true
  
  include MemoryValidation
  include ActionView::Helpers::SanitizeHelper
  include Lockable
  #default_scope {order("recordings.number ASC")} 
  #before_validation :rationalise_purchasability_of_resourcess do we nbeed this?
  
  ###########################.  Transcription.  #####################################################
  # maps the column :transcription_status to these readable names
  enum :transcription_status, { 
    not_requested: 0, 
    pending: 1, 
    processing: 2, 
    completed: 3, 
    failed: 4 ,
    enqueued: 5
  }
  
  #priority. set if transcription required leave null if not required

 #scope :for_transcription, ->(user) {
 #  joins(happening: :course).where(
 #    "(happenings.happenable_id = :centre_id AND happenings.type != :meet_type) OR 
 #     (courses.centre_id = :centre_id AND happenings.type = :meet_type)",
 #    centre_id: user.centre_id,
 #    meet_type: 'Meet'
 #  )
 #}
  scope :for_transcription, ->(user) {
    joins(happening: :course).where(
      happenings: { happenable_id: user.centre_id }
    ).where.not(
      happenings: { type: 'Meet' }
    ).or(
      joins(happening: :course).where(
        courses: { centre_id: user.centre_id },
        happenings: { type: 'Meet' }
      )
    ).distinct 
  }


###############################   callbacks  ######################################
  before_validation :ensure_strings4text
  before_validation :sanitize_content
  before_validation :set_number, :if => Proc.new { |r| r.new_record? } 
  
  before_save :sync_searchable_text, if: -> { title_changed? || writeup.changed? }
  before_save :clear_error_message, if: ->  { transcription_status_changed? and (transcription_status == "failed") }
  before_destroy :verify_destroy 
  
  before_validation :reset_when_transcript_set_to_not_requested, if: ->  { transcription_status_changed? and (transcription_status == "not_requested") }
###############################   Relationships  ######################################

  belongs_to :happening 
 # belongs_to  :meet, :class_name=>"Meet",:foreign_key=> :happening_id
 # belongs_to :talk_type
 

  has_many :contributions, :dependent => :destroy
  has_many :speakers, :through=> :contributions
  has_many :resources , :inverse_of => :recording
  has_many :acquired_resources, through: :resources  
  has_many :acquirable_resources, -> { where("formats.downloadable = true").joins(:format,:talk_type)}, class_name: "Resource"
  has_many :allocated_items, through: :resources   
  has_many :downloadable_resources, -> { where("formats.downloadable = true").joins(:format,:talk_type)}, class_name: "Resource"
  
  has_many :transcription_logs, dependent: :destroy
  has_many :transcription_jobs, dependent: :destroy
   
  accepts_nested_attributes_for :resources
  has_rich_text :writeup
  
  # => this can be delete 10-3-2026
#  # used to query the attached ActionText directly
#   has_one :action_text_rich_text,
#     class_name: 'ActionText::RichText',
#     as: :record
     
 
###############################   validations  ######################################

  validates_presence_of :title , :start_datetime, :number
  validates_uniqueness_of :title, :scope => :happening_id 
 # validates_uniqueness_of :number, :scope => :happening_id 
  validates_length_of :title,   maximum: 80
  validate :within_parent_dates, :unless => Proc.new { |r| r.start_datetime.blank? }
  validate :validate_unique_resources
  validates_associated :resources, :message=> "you ho"
  # Validation: cannot be 'completed' without a file
  validate :status_cannot_change_if_transcript_attached, on: :update
  ###############################   scope  ######################################
  scope :by_happening,lambda{|happening_id | where(:happening_id =>happening_id)}
  
  scope :for_my_downloads_grouped_by_happening_id, lambda{|rec_ids| where(id: rec_ids)
    .includes( contributions: :speaker).references(:contributions)
    .order("recordings.number, contributions.main DESC").group_by{|recording|recording.happening_id}
  }

  scope :for_sound_admin_grouped_by_happening_id, lambda{|happening_ids| where(happening_id: happening_ids)
    .includes( contributions: :speaker).references(:contributions)
    .order("recordings.number, contributions.main DESC, contributions.created_at").group_by{|recording|recording.happening_id}
  }
  

    

  scope :by_transcription_status, ->(statuses) { where(transcription_status: statuses) }  


  def best_transcribable_resource
    # Priority: Movie(2), Uncompressed(5), MP3(1)
    [2, 5, 1].each do |id|
      match = resources.with_attached_file.find { |r| r.format_id == id }
      return match if( match and match.file.blob.service.exist?(match.file.key))
    end
    nil
  end

  
   
   def self.enqueue_next_transcription
     # Check for any job in the 'transcribe' queue that hasn't finished yet.
     # This covers Ready, Claimed, and Scheduled statuses.
     where(transcription_status: [:processing, :enqueued])
         .where("updated_at < ?", 1.hours.ago)
         .update_all(transcription_status: :failed, error_message: "Process timed out.")
     return if SolidQueue::ReadyExecution.exists?(queue_name: "transcribe") || 
               SolidQueue::ClaimedExecution.exists?(job_id: SolidQueue::Job.where(queue_name: "transcribe"))

     transaction do
       # 1. Clean up "Stuck" records (Any state that isn't completed/failed but hit the limit)
       stuck_recs = where(transcription_status: [:pending, :processing, :enqueued])
                    .where("transcription_attempts >= 3")

       stuck_recs.each do |rec|
         # Mark as failed so the Watchdog stops trying to enqueue it
         rec.update!(
           transcription_status: :failed, 
           error_message: "Max attempts (3) reached. The process failed to complete."
         )
  
         # Send the alert
         logger.debug "[transcription] Max attempts reached for Recording #{rec.id}. Sending alert."
         FailedTranscriptionMailer.transcription_failed_alert(rec).deliver_later
        end
       # Your locking logic is excellent for preventing double-processing
       next_rec = where(transcription_status: :pending)
                  .where("transcription_attempts < 3")
                  .where.not(priority: nil)
                  .order(priority: :desc, happening_id: :desc, number: :asc)
                  .lock("FOR UPDATE SKIP LOCKED")
                  .first

       if next_rec
         # We mark it as 'enqueued' or similar here if you have a status for it,
         # to prevent the Watchdog from seeing it as 'pending' in the split second 
         # before the job actually starts and sets it to 'processing'.
          next_rec.increment!(:transcription_attempts)
         next_rec.update!(
           transcription_status: :enqueued,
           transcribed_at: Time.current
         )
         TranscribeRecordingJob.perform_later(next_rec.id)
          return true # Explicitly return success
       else
         logger.debug "[Queue] No transcribable recordings found or max attempts reached."
         return false # Explicitly return that no work was found
       end
     end
   end


  def length
      a  = self.duration.divmod(5)
      
      length = ((a[1] < 3) ?  a[0]* 5 : (a[0] + 1)* 5  )
      length 
  end
    
 
  
 
  
  def set_number


    no = Recording.by_happening(happening_id).maximum(:number).to_i 
    self.number = no +1
  end
  
  def remove_transcript!
    unless raw_transcript.attached?
      errors.add(:base, "No transcript is attached to this recording")
      return false
    end
    transaction do
       raw_transcript.purge_later
       update(transcription_status: "not_requested", priority: nil,transcription_attempts: 0)
    end
  end
  
  # Helper for the view to check physical existence safely
  def raw_transcript_physically_exists?
    raw_transcript.attached? && raw_transcript.blob.service.exist?(raw_transcript.key)
  end
  
private
  
  def reset_when_transcript_set_to_not_requested
     self.priority = nil
     self.transcription_attempts =0
  end
 
  
  def clear_error_message
    self.error_message = ""
    self.transcription_attempts =0
  end

  def centre_id
    case happening.type
      when "Meet"
        centre_id = happening.happenable.centre_id
      when "Event"
        centre_id = happening.happenable_id
    end
    return centre_id
  end
  
  def self.reorder_sessions(happening_id, recording_id, index)
    logger.debug "\n\nhreorder_sessions #{happening_id}, #{recording_id}, #{index}\n\n"
    # find happening recording ids excluding moved recording ordered by number
    # add moved recording id at position
    # create new number value array
    # update records
    recording_ids = Recording.where(happening_id: happening_id ).where.not(id:recording_id).ids
    recording_ids.insert(index.to_i, recording_id.to_i)
    logger.debug "\n\nrecording_ids #{recording_ids} size #{recording_ids.length}\n\n"
    values =[]
    recording_ids.each_with_index do |r,i|
      values << {"number"=> (i + 1)}
    end
    return [recording_ids,values]
    
  end
  

  

  
  def sync_searchable_text
   
      self.searchable_text = "#{title} #{writeup.to_plain_text}"
  
    end
  
  
  def within_parent_dates
    errors.add(:start_datetime, "must be within parent dates") if( 
                     self.start_datetime.to_date < self.happening.start_date)
     if self.happening.end_date
        errors.add(:start_datetime, "must be within Event dates") if( 
                             self.start_datetime.to_date > self.happening.end_date)
     end
  end

   def validate_unique_resources
      validate_uniqueness_of_in_memory(resources, [:format_id], 'Duplicate formats.')
  end

  
  def verify_destroy
     allow_destroy = true
      unless resources.empty?           
         errors.add("Resources", " exist for this Recording")
         allow_destroy=   false
      end

      (throw :abort )unless allow_destroy
  end
  def sanitize_content
    self.content =sanitize(content, :tags=> %w(h5))
  #                ActionView::Base.full_sanitizer.sanitize(html_string, :tags => %w(img br p), :attributes => %w(src style))

  end

  def ensure_strings4text
     (self.content = "")if self.content.blank?
      (self.recording_notes= "")if self.recording_notes.blank?
  end
  
  def status_cannot_change_if_transcript_attached
    # 1. If there's no transcript, or it's being deleted right now, allow the change.
    return unless raw_transcript.attached?
    return if raw_transcript.attachment.marked_for_destruction?

    # 2. If the user (via the view) tries to change status to anything but 'completed'
    # while the transcript file still exists, block it.
    if transcription_status_changed? && transcription_status != 'completed'
      errors.add(:transcription_status, "is locked while a transcript is attached. Delete the transcript first.")
    end
  end



  
 
end


