# app/models/recording.rb  v1.3
class Recording < ApplicationRecord
  self.ignored_columns =['content',"recording_notes"]
  has_one_attached :audio_file
  has_one_attached :raw_transcript, service: :raw_transcripts 
  has_one_attached  :caption_file, service: :raw_transcripts 
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
    bypassed:   0,  
    requested:  1, 
    dispatched: 2, #Set by the Server's Scout logic immediately after it is selected to be sent to M4's TranscriptionDispatcherJob
    received:   3, #when the TranscriptionDispatcherJob receives the ids it responds to
                    #update server recording.transcription_status as :received      
    preparing: 4,  # The very first line of TranscriptionPrepJob.perform. This confirms the worker has moved the job from its   
    prepared: 5,  # The TranscriptionPrepJob.perform.completes ans the recording is ready for transcription 
    processing: 6,           #local queue to an active CPU thread.
    processed:  7,# Set when the server receives the transcription back from the work
    failed:     8,   #Triggered by any rescue block in the TranscriptionPrepJob or the final transcription job. 
                  #This ensures the     Librarian knows to stop waiting for a result.
    completed:  9, #Set during the Step 30 "Tidy Up". Once the Server confirms the JSON is safely in Active Storage, 
                  #it flips this final switch.
  }
  
  # Change this value to adjust your "Buffer" size
  PREP_BUFFER_LIMIT = 5 
  
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
   
  # around_update :sync_job_receipt_on_failure,  if: -> {transcription_status_changed? && failed?}
   
   after_update_commit :remove_monitor_card, if: :should_hide_card?
   after_update_commit :broadcast_tracker_update, if: :saved_change_to_transcription_status?
   after_update_commit :broadcast_management_update, if: :saved_change_to_transcription_status?
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
  has_many :job_receipts, dependent: :destroy
  accepts_nested_attributes_for :job_receipts
  accepts_nested_attributes_for :resources
  has_rich_text :writeup
  

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
    
 #   validate :brickwall for testing
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
      # .exist? will naturally raise Seahorse::Client::NetworkingError if the net is down
      return match if match && match.file.blob.service.exist?(match.file.key)
    end
    nil
  end


  def log_status(message)
    # 1. Force everything to string with interpolation
    safe_cage = "#{ENV['QUEUES'] == 'transcription_heavy' ? 'MUSCLE' : 'SYSTEM'}"
    safe_msg  = "#{message}"

    # 2. Use a block to catch the EXACT error during the save
    begin
      new_log = transcription_logs.create!(message: "[#{safe_cage}] #{safe_msg}")

   
    rescue => e
      # This will tell us if the DB is rejecting the string
      puts "!!! LOG_STATUS INTERNAL ERROR: #{e.message}"
      Rails.logger.error "log_status error: #{e.message}"
    end
  end
  

  

  def length
      a  = self.duration.divmod(5)
      
      length = ((a[1] < 3) ?  a[0]* 5 : (a[0] + 1)* 5  )
      length 
  end

  
  def self.clean_pipeline_collect_next_recording_ids_for_worker(limit:)
    # 1. THE JANITOR (Now runs every 5-10 mins)
    # Cleans up any 'preparing' or 'processing' jobs that haven't 
    # checked in (updated_at) for over 2 hours.
    cleanup_stale_transcriptions
     logger.debug "\n\ncleaned stale transcriptions\n\n"
    # Calculate how many slots are open in the buffer
     # (requested -> preparing -> prepared)
    current_in_flight = where(transcription_status: [:processing, :dispatched, :received, :preparing,:prepared]).count
    slots_available = limit - current_in_flight
     
    # 2. Scout for NEW work (Stage 1: requested -> preparing)
    target_ids =[]
    if slots_available > 0
      TranscriptionLog.where(recording_id: target_ids).delete_all
     target_ids= scout_and_collect_ids_for_worker(limit: slots_available)
     
    end
    target_ids
  end
  
  
  
  
  def set_number
    no = Recording.by_happening(happening_id).maximum(:number).to_i 
    self.number = no +1
  end
  
  def remove_raw_transcript
    success = ActiveRecord::Base.transaction do
      # 1. Kill the current attachment link and blob
      raw_transcript.purge if raw_transcript.attached?
      caption_file.purge if caption_file.attached?
      # 2. Reset status
      update!(transcription_status: :bypassed)
      true
    end

    # 3. Clean up orphans outside the lock to keep DB snappy
    if success
      purge_ghost_blobs(:raw_transcript, "txt")
      purge_ghost_blobs(:caption_file, "vtt")
    end
    success
    rescue StandardError => e
      Rails.logger.error "Remove Transcript Failed: #{e.message}"
      false
  end
  
  def purge_ghost_blobs(attachment_name, extension)
    # 1. Generate the expected key (e.g., "1089_S8_Title.txt")
    custom_key = "#{identifier}.#{extension}"
  
    # 2. Identify the 'official' blob currently linked to the record
    attachment = send(attachment_name)
    valid_blob_id = attachment.attached? ? attachment.blob_id : nil
  
    # 3. Find all blobs with this key created more than 1 hour ago
    ActiveStorage::Blob.where(key: custom_key)
                       .where("created_at < ?", 1.hour.ago)
                       .find_each do |blob|
    
      is_official = (blob.id == valid_blob_id)
      file_exists = blob.service.exist?(blob.key)
  
      # Purge if it's an old version (ghost) OR if the file is physically missing (broken)
      if !is_official || !file_exists
        Rails.logger.info "Janitor: Purging #{is_official ? 'Zombie' : 'Ghost'} #{extension} blob #{blob.id}"
        blob.purge
      end
    end
  end
  
  # Helper for the view to check physical existence safely
  def raw_transcript_physically_exists?
    raw_transcript.attached? && raw_transcript.blob.service.exist?(raw_transcript.key)
  end
  
  def identifier
    safe_name("#{happening_id}_S#{number}_#{title}")
  end
  
  def archive_folder
   safe_name("#{happening_id}_#{happening.title}")                   # 7. Clean up ends
  end
  
  def safe_title
     safe_name("#{happening_id}_#{title}")
  end
 
  
  def self.cleanup_stale_transcriptions
      # Target all active processing states that have stalled past 90 minutes
      where(transcription_status: [:dispatched, :received, :preparing, :prepared, :processing, :processed])
           .where("updated_at < ?", 90.minutes.ago)
           .find_each do |recording|
             logger.debug "\n\n rec #{recording.id } #{recording.number }\n\n"
        # 🚧 THE GATEWAY: Open a rescue block for EACH individual recording
        begin
          transaction do
           # if recording.raw_transcript.attached?
           #   # 🟢 PATH 1: GHOST SUCCESS
           #   # The file is safely here. Quietly align the status to completed.
           #   recording.update!(transcription_status: :completed, transcribed_at: recording.updated_at)
           #   logger.info "Janitor: Recording ##{recording.id} auto-healed to completed."
           # else
              # 🔴 PATH 2: TRUE TIMEOUT
              # No file exists. Purge stray captions and quietly fail it.
              recording.caption_file.purge if recording.caption_file.attached?
              recording.raw_transcript.purge if recording.raw_transcript.attached?
              recording.failed!
              logger.warn "Janitor: Recording ##{recording.id} timed out and was marked failed."
         #   end
          end # ↩️ The transaction ends here. If validations fail, it rolls back SQL commands.
          
        rescue ActiveRecord::RecordInvalid => e
          # 🛡️ THE EXCEPTION CATCH: Traps validation errors, prints them, 
          # and 'next' safely advances the loop to the next recording.
          logger.error "🚨 Janitor Exception on Recording ##{recording.id}: #{e.message}"
          next
        end
      end
  end

  def self.scout_and_collect_ids_for_worker(limit:)
    transaction do
      # 1. Grab the IDs and lock them immediately
      # SKIP LOCKED ensures multiple workers don't grab the same work
      target_ids = where(transcription_status: [:requested,])
                   .where.not(priority: nil)
                   .order(priority: :desc, id: :asc)
                   .limit(limit)
                   .lock("FOR UPDATE SKIP LOCKED")
                   .pluck(:id)

      return [] if target_ids.empty?

      # 2. Bulk update the status so they aren't "requested" anymore
      # update_all is a single SQL command: UPDATE recordings SET status = ... WHERE id IN (...)
      where(id: target_ids).update_all(
        transcription_status: :dispatched, 
        updated_at: Time.current
      )
      TranscriptionLog.where(recording_id: target_ids).delete_all
      # 3. Return the array of IDs (e.g., [101, 102, 105])
      target_ids
    end
  end



   def editable_when_locked
     # Otherwise, fall back to your hardcoded default array.
     @dynamic_editable_fields || [] #"transcription_status","transcribed_at"
   end
   
   def editable_when_locked=(array)
     # Convert everything to strings to ensure it plays nice with Lockable
     @dynamic_editable_fields = Array(array).map(&:to_s)
   end
  
   private
   
   def safe_name(name)
     return "" if name.blank?

     name
       .unicode_normalize(:nfd)      # 1. é -> e + ´
       .gsub(/\p{M}/, '')            # 2. Delete the ´
       .gsub('&', 'and')             # 3. & -> and
       .gsub(/["']/, '')             # 4. Remove quotes entirely
       .gsub(/\s+/, '_')             # 5. Space -> _
       .gsub(/[^\w\(\)\-]/, '_')     # 6. REMOVE ALL OTHER punctuation (including .) -> _
       .gsub(/_{2,}/, '_')           # 7. Collapse multiple underscores
       .gsub(/^_|_$/, '')            # 8. Clean the ends
   end
   
  def centre_id
    if( happening.type =="Meet")
        happening.happenable.centre_id
     else
        happening.happenable_id
    end
    
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
  
  def reset_when_transcript_set_to_bypassed
     self.priority = nil
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
  
  def should_hide_card?
    # Hide if the job is just 'prepared' (waiting) or 'completed'
    saved_change_to_transcription_status? && ["prepared", "completed"].include?(transcription_status)
  end

  def remove_monitor_card
    broadcast_remove_to(
      "transcription_monitor_channel",
      target: "transcription_monitor_job_recording_#{id}"
    )
  end
  
  def broadcast_tracker_update
    # Define the active statuses we care about for the tracker
    active_statuses = [:dispatched, :received, :preparing, :prepared, :processing, :processed]
    row_id = "tracker_row_recording_#{id}"
    if active_statuses.include?(transcription_status.to_sym)
      # If the recording is now active, replace/update its specific row
      broadcast_append_to(
        "transcription_monitor_channel",
        target: "status_tracker_rows",
        partial: "transcription/job_receipts/status_tracker_row",
        locals: { recording: self }
      )
    else
      # If it moved to a status NOT in our list (e.g., :completed or :failed), 
      # remove it from the tracker table entirely.
      broadcast_remove_to(
        "transcription_monitor_channel",
        target: "tracker_row_recording_#{id}"
      )
    end
    broadcast_update_to(
      "transcription_monitor_channel",
      target: "failed_jobs_counter",
       html: Recording.failed.size 
    )
  end
  
  def broadcast_management_update
    # We target the specific Turbo Frame ID we defined in the partial
    broadcast_replace_to(
      "transcription_management_channel",
      target: "recording_#{id}_transcription",
      partial: "transcription/recordings/recording_links",
      locals: { recording: self }
    )
  end
  
  def brickwall
  	self.errors.add(:base, "brick_wall!")
  	return false
  end
  
#  def verify_destroy
#  	allow_destroy=   true
#  	
#  	errors.add("base", "brick wall.")
#  	allow_destroy =   false
#  	(throw :abort )unless allow_destroy
#  end

end


