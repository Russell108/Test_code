class Recording < ApplicationRecord
  self.ignored_columns =['content',"recording_notes"]
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
  enum :transcription_status,{
    bypassed: 0,  
    requested: 1, 
    preparing: 2, # Worker B is currently unzipping/downloading
    prepared: 3,  # Worker B is DONE; Chunks are ready for Worker A
    processing: 4,# Worker A is actively transcribing not needed
    completed: 5, 
    failed: 6 
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
  before_validation :set_number, :if => Proc.new { |r| r.new_record? } 
  
  before_save :sync_searchable_text, if: -> { title_changed? || writeup.changed? }
  before_destroy :verify_destroy 
  
  before_validation :reset_when_transcript_set_to_bypassed, if: ->  { transcription_status_changed? and (transcription_status == "bypassed") }
  # 2. THE ATTACHMENT SYNC: Ensure status is 'completed' if file exists
   before_validation :sync_status_with_attachment, if: :new_raw_transcript_attached?
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
  validate :within_parent_dates, :unless => Proc.new { |r| r.happening_id.blank? || r.start_datetime.blank? }
  validate :validate_unique_resources
  validates_associated :resources, :message=> "you ho" 
  
  # 1. THE STATUS GUARD: Prevent changing status once it is 'completed'
 #   validate :transcription_status_cannot_be_changed_from_completed , on: :update
    validate :status_must_match_attachment
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

  
  def log_status(message)
    # Detect the "Cage" based on the environment variable we set in systemd
    cage = ENV['QUEUES'] == 'transcription_heavy' ? "MUSCLE" : "SYSTEM"
    
    # In development on your Mac, you can add more flair
  #  location = Rails.env.development? ? "MAC" : "SERVER"
    
    transcription_logs.create!(
      message: "[#{cage}] #{message}"
    )
  end


  def length
      a  = self.duration.divmod(5)
      
      length = ((a[1] < 3) ?  a[0]* 5 : (a[0] + 1)* 5  )
      length 
  end
    
  def self.enqueue_next_transcription
    Rails.logger.debug "\n\nenqueue_next_transcription\n\n"
    puts"\nenqueue_next_transcription"
    # 1. THE JANITOR: Clean up ghosts before starting new work
    self.cleanup_stale_transcriptions
  
    # 2. THE DISPATCHER: Rails 8 style transaction
    transaction do
      # Fetch next recording with Row Locking to prevent double-processing
      next_rec = where(transcription_status: :requested) # Your plan said 'requested'
                 .where.not(priority: nil)
                 .order(priority: :desc, id: :asc)
                 .lock("FOR UPDATE SKIP LOCKED")
                 .first
      return unless next_rec
    
       
       
        next_rec.purge_ghost_raw_transcript_blobs
      
        job = TranscriptionJob.create!(recording: next_rec, status: :processing)

        # Move status to preparing (Don't set transcribed_at yet!)
        next_rec.update!(transcription_status: :preparing)
      
        # The Handoff to the System Cage (Cores 0-1)
        TranscriptionPrepJob.perform_later(job.id)
      
     
    end
  end


  
 
  
  def set_number


    no = Recording.by_happening(happening_id).maximum(:number).to_i 
    self.number = no +1
  end
  
  def deliberate_clear_transcript!
    ActiveRecord::Base.transaction do
      # 1. Lock the recording to prevent User A/B race conditions
      lock! 

      # 2. Identify the 'official' blob if it exists
      valid_blob_id = raw_transcript.attached? ? raw_transcript.blob_id : nil

      # 3. THE GHOST HUNTER: Kill matching keys, but ONLY the old ones
      # This leaves "User B's" 2-minute-old upload alone.
      ActiveStorage::Blob.where(key: your_custom_key_logic)
                         .where.not(id: valid_blob_id)
                         .where("created_at < ?", 1.hour.ago)
                         .find_each(&:purge)

      # 4. THE OFFICIAL PURGE: If a valid one exists, kill it now
      raw_transcript.purge if raw_transcript.attached?

      # 5. THE RESET: Update status
      update!(transcription_status: :bypassed)
    end
  rescue StandardError => e
    Rails.logger.error "Manual Janitor Failed: #{e.message}"
    raise e # Re-raise so the UI knows it failed
  end
  

  

  
  def remove_raw_transcript
    success = ActiveRecord::Base.transaction do
      # 1. Kill the current attachment link and blob
      raw_transcript.purge if raw_transcript.attached?

      # 2. Reset status
      update!(transcription_status: :bypassed)
      true
    end

    # 3. Clean up orphans outside the lock to keep DB snappy
    purge_ghost_raw_transcript_blobs if success
    success
    rescue StandardError => e
      Rails.logger.error "Remove Transcript Failed: #{e.message}"
      false
  end
  
  def purge_ghost_raw_transcript_blobs
  
    filename = "#{happening_id}_S#{number}_#{title}".gsub(/[^\w\.\-]/, '_')
    custom_key = "#{filename}.txt"
    
    # 1. Identify the 'official' blob if it exists
    valid_blob_id = raw_transcript.attached? ? raw_transcript.blob_id : nil
    
    # 2. Find ALL blobs using this key (older than 1 hour)
    ActiveStorage::Blob.where(key: custom_key)
                       .where("created_at < ?", 1.hour.ago)
                       .find_each do |blob|
    
      # 3. THE PHYSICAL CHECK: If it's not our official one OR the file is physically missing
      # We purge if:
      #   - It's a ghost (not the official ID)
      #   - OR it's the official one but the actual file is gone (broken link)
      is_official = (blob.id == valid_blob_id)
      file_exists = blob.service.exist?(blob.key)
    
      if !is_official || !file_exists
        Rails.logger.info "Janitor: Purging #{is_official ? 'Zombie' : 'ghost'} blob #{blob.id}"
        blob.purge
      end
    end
  
  
  end 
  
  
  # Helper for the view to check physical existence safely
  def raw_transcript_physically_exists?
    raw_transcript.attached? && raw_transcript.blob.service.exist?(raw_transcript.key)
  end
  
  def custom_key_for_transcript
    filename ="#{happening_id}_S#{number}_#{title}".gsub(/[^\w\.\-]/, '_').gsub('&', 'and')
                .gsub(/[^\w\.\-\(\)\&]/, '_')
      custom_key = "#{filename}.txt"
  end

  private

  def self.cleanup_stale_transcriptions
    # Match the timeframe to the message (90 mins is safer for huge files)
    TranscriptionJob.where(status: :processing)
                    .where("updated_at < ?", 90.minutes.ago)
                    .find_each do |job|
      transaction do
        job.update!(status: :failed, ended_at: Time.current)
      
        job.recording.update!(
          transcription_status: :failed,
          error_message: "Stale Job: No activity detected for 90 minutes. Muscle Cage timed out."
        )
      
        job.recording.log_status("System: Stale job detected. Marking as Failed for manual review.")
      end
    end
  end
  
  def reset_when_transcript_set_to_bypassed
     self.priority = nil
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


  
  def status_must_match_attachment
    if raw_transcript.attached? && !completed?
      errors.add(:transcription_status, "must be 'completed' because a transcript file is attached.")
    end
    
    if !raw_transcript.attached? && completed?
      errors.add(:transcription_status, "cannot be 'completed' without an attached transcript file.")
    end
  end


  def new_raw_transcript_attached?
    # Inspects ActiveStorage's internal change tracker for a new file assignment
    attachment_changes['raw_transcript'].is_a?(ActiveStorage::Attached::Changes::CreateOne)
  end
  
  def sync_status_with_attachment
    logger.debug "\n\nsync_status_with_attachment\n\n"
    logger.debug "\n\ntranscription_status #{transcription_status}\n\n"
    # If the Banker finished but the Architect hasn't run yet, this is the safety net
    if raw_transcript.attached? && !completed?
      self.transcription_status = :completed
    end
  end



  
 
end


