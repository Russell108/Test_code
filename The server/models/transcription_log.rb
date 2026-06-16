class TranscriptionLog < ApplicationRecord
  belongs_to :recording
   after_create_commit :broadcast_to_monitor

   private
   
   def broadcast_to_monitor
     # 1. Ensure the Card exists (The "Self-Healing" part)
     broadcast_append_to(
       "transcription_monitor_channel",
       target: "transcription_monitor_jobs",
       partial: "transcription/job_receipts/transcription_monitor_job",
       locals: { recording: recording }
     )
   end
end
