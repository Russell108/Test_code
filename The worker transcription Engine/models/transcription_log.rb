class TranscriptionLog < ApplicationRecord
  
#  # This sends the message to the 'recording_XX' stream automatically
# #  after_create_commit
#  after_create -> { 
#    Rails.logger.debug "\n\nTranscriptionLog after_create_commit ->\n\n"
#    broadcast_append_to(
#   #   recording, 
#      "transcription_monitor_channel",
#      target: "logs_recording_#{recording_id}",
#      partial: "transcription/transcription_logs/transcription_log",
#      locals: { transcription_log: self }
#    ) 
#  }
  
  
  
  
  
  belongs_to :job_receipt
end
