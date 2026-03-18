# app/jobs/transcription_watchdog_job.rb

class TranscriptionWatchdogJob < ApplicationJob
  queue_as :default

  def perform
    result = Recording.enqueue_next_transcription
    
    unless result
      # Optional: You can log or simply exit gracefully
      logger.info "Watchdog checked: Nothing to enqueue."
    end
  end
end