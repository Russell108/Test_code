# app/jobs/transcription_watchdog_job.rb
class TranscriptionWatchdogJob < ApplicationJob
  queue_as :default

  def perform
    # If the queue is empty but recordings are pending, this starts the chain
    Recording.enqueue_next_transcription
  end
end