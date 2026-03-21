# app/jobs/transcription_dispatcher_job.rb
class TranscriptionDispatcherJob < ApplicationJob
  queue_as :default

  def perform
    # Just call the model method we just created
    Recording.enqueue_next_transcription
  end
end