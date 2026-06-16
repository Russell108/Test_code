class Api::V1::Transcription::TranscriptionLogsController <  Api::V1::Transcription::BaseController
  # 1. Bypass CSRF for the M4's API calls


  def create
    logger.debug "\n\ntranscription_log_params #{transcription_log_params}\n\n"
    
        message = transcription_log_params[:message]&.strip
        recording_id = transcription_log_params[:recording_id]

        # 🌟 WIPE PREVIOUS LOGS: If a new job starts with the "😀" emoji
        if message == "😀" && recording_id.present?
          # 1. Purge the database histories for this recording
          TranscriptionLog.where(recording_id: recording_id).destroy_all
      
          # 2. Live-Clear the UI console wrapper so it doesn't show stale text
          Turbo::StreamsChannel.broadcast_update_to(
            "logs_recording_#{recording_id}",
            target: "logs_recording_#{recording_id}",
            html: "" # Wipes the container clean
          )
        end
   
   
    
    # 3. Create the log in the S Server database (The "Historian")
    logger.debug "\n\ntranscription_log_params #{transcription_log_params}\n\n"
    @transcription_log = TranscriptionLog.create(transcription_log_params)
    recording = @transcription_log.recording
#   # 4. "Self-Healing" Broadcast: 
#   # If the monitor card is missing or was removed, this re-injects it.
#   Turbo::StreamsChannel.broadcast_append_to(
#     "all_transcriptions",
#     target: "transcription_monitor_jobs",
#     partial: "transcription/job_receipts/monitor_job",
#     locals: { recording: recording }
#   )
#
#   # 5. Live Log Broadcast: 
#   # Appends the new line directly into the card's console window.
#   @transcription_log.broadcast_append_to(
#     "logs_recording_#{recording.id}",
#     target: "logs_recording_#{recording.id}",
#     partial: "transcription/transcription_logs/transcription_log",
#     locals: { transcription_log: @transcription_log }
#   )

    render json: { success: true }, status: :created
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Recording not found" }, status: :not_found
  end
  
  private
  def transcription_log_params
    # This allows the worker to update the status (and hostname if we decide to use it later)
    params.require(:transcription_log).permit(:message, :recording_id)
  end
end
