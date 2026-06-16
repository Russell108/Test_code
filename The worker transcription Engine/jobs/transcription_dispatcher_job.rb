# app/jobs/transcription_dispatcher_job.rb (On the M4)
class TranscriptionDispatcherJob < ApplicationJob
  
  queue_as :default

  def perform
    @recording_proxy = RecordingProxy.new
    begin
      #  Ask the server for the batch
      ids = @recording_proxy.index_for_next_recordings(limit: 5)
      puts "line 11"
      # SUCCESS PATH: If the server is reachable, we reset our "downtime clock"
      # This prevents the 10-minute alert from firing if it was just a 2-minute blip.
      clear_connection_fault_timer 

      if ids.any?
       ids.each do |id|
         job_receipt =JobReceipt.create!(recording_id: id, status: :received)
          puts "job_receipt_id #{job_receipt.inspect}"
          TranscriptionPrepJob.perform_later(job_receipt.id) 
          @recording_proxy.update(id, {transcription_status: 'received'})
        end
        
      else
        # OPTIONAL: A simple log for your M4 Console 
        Rails.logger.info "[M4] Check-in: No new recordings found."
      end

     rescue => e
      # SYSTEM FAULT: Handled by the threshold logic we discussed
      # No JobReceipt is created on the server [cite: 11]
      handle_connectivity_failure(e.message) 
    end
  end
  
  private

  # resets the failure state when the handshake succeeds
  def clear_connection_fault_timer
    if Rails.cache.exist?("server_unreachable_since")
      Rails.logger.info "✅ [M4] Connection restored. Resetting fault timers."
      Rails.cache.delete("server_unreachable_since")
      Rails.cache.delete("alert_sent_recently")
    end
  end

  # tracks downtime and alerts only after a 10-minute threshold
  def handle_connectivity_failure(error_message)
    # 1. Record the first time we hit a wall
    first_failed_at = Rails.cache.fetch("server_unreachable_since") { Time.now }
  
    # 2. Calculate how long we've been in the dark
    downtime_seconds = (Time.now - first_failed_at).to_i
    downtime_minutes = downtime_seconds / 60
  
    # 3. Log to the M4 Console (Step 35)
    Rails.logger.error "⚠️ [M4] Server unreachable for #{downtime_minutes}m. Error: #{error_message}"

    # 4. Threshold Check (10 Minutes)
    if downtime_minutes >= 10
      trigger_system_alert(downtime_minutes, error_message)
    end
  end

  def trigger_system_alert(minutes, error)
    # Ensure we only send one email per hour during a long outage
    return if Rails.cache.read("alert_sent_recently")

    # This is the "Red Phone" to the Systems Engineer
    SystemNotifier.critical_alert(
      subject: "Infrastructure Alert: Transcription Server Offline",
      body: "M4 Worker has been unable to reach the Server for #{minutes} minutes. Last Error: #{error}"
    ).deliver_now

    Rails.cache.write("alert_sent_recently", true, expires_in: 1.hour)
  end
  
end