class TranscriptionJob < ApplicationRecord
  
  
    ###############################   relationships  ######################################
  belongs_to :recording
  has_many :transcription_chunks, dependent: :delete_all
  
  enum :status, { 
    bypassed: 0,  
    pending: 1, 
    preparing: 2, # Worker B is currently unzipping/downloading
    prepared: 3,  # Worker B is DONE; Chunks are ready for Worker A
    processing: 4,# Worker A is actively transcribing
    completed: 5, 
    failed: 6 
  }
  
    ###############################   callbacks  ######################################
  # The Final Cleanup: Triggered by job.completed!
    after_commit :purge_database_chunks, if: :finalized?
    
  # Trigger broadcasts only after the database transaction is finished
 # after_create_commit :broadcast_to_monitor, if: :saved_change_to_completed_status?
  # for testing purposes only
 # after_update_commit :broadcast_to_monitor
 #after_commit :broadcast_to_admin_page, on: [:create, :update], if: :saved_change_to_completed_status?
 # Ensure this matches your existing status column


  ###############################   scope  ######################################
 scope :by_status, ->(status) { where(status: status) }  
 
   ###############################   public methods  ######################################
 def broadcast_to_admin_page
   # This sends ONE broadcast containing all instructions
   Turbo::StreamsChannel.broadcast_render_to(
     "transcription_monitor_channel",
     template: "transcription/transcription_jobs/admin_update",
     locals: { transcription_job: self }
   )
 end
 
  def all_chunks_complete?
   #used in   TranscribeChunkJob < ApplicationJob
    transcription_chunks.present? && transcription_chunks.all?(&:completed?)
  end




  # Define the scope here
  scope :recently_completed, -> { 
    completed
      .includes(:recording)
      .order(id: :desc)
      .limit(5) 
  }

# def broadcast_to_admin_page
#   # 1. Prepend the new row to the table
#   broadcast_prepend_to(
#     "transcription_monitor_channel",
#     target: "historical_jobs",
#     partial: "transcription/transcription_jobs/transcription_job",
#     locals: { transcription_job: self }
#   )
#
#   # 2. Remove the 6th row to keep the list at 5
#   broadcast_action_to(
#      "transcription_monitor_channel",
#      action: :remove,
#      target: nil,
#      targets: "#historical_jobs  tr:nth-child(6)",
#       partial: "transcription/transcription_jobs/transcription_job"
#    )
#
#   # 3. Update the counter
#   broadcast_update_to(
#     "transcription_monitor_channel",
#     target: "failed_jobs_counter",
#     html: Recording.failed.count.to_s
#   )
# end
  ###############################   private methods  ######################################
 private
 
 def finalized?
   # Only purge if the job reached a terminal state
   completed? || failed?
 end

 def purge_database_chunks
   # Use destroy_all if chunks have ActiveStorage/callbacks
   # Use delete_all if they are just database rows (much faster)
   transcription_chunks.destroy_all
 end
 

  def saved_change_to_completed_status?
    saved_change_to_status?(to: "completed")
   # saved_change_to_status? && status == 'completed'
  end
  
  def broadcast_to_monitor
    # 1. Prepend the new row to the table
    broadcast_prepend_to(
      "transcription_monitor_channel",
      target: "historical_jobs",
      partial: "transcription/transcription_jobs/transcription_job",
      locals: { transcription_job: self }
    )

    # 2. Remove the 6th row to keep the list at 5
    broadcast_action_to(
       "transcription_monitor_channel",
       action: :remove,
       target: nil,
       targets: "#historical_jobs tr:nth-child(6)",
        partial: "transcription/transcription_jobs/transcription_job"
     )

    # 3. Update the counter
    broadcast_update_to(
      "transcription_monitor_channel",
      target: "total_jobs_counter",
      html: TranscriptionJob.count.to_s
    )
  end
end
