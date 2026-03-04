# app/jobs/transcribe_recording_job.rb
class TranscribeRecordingJob < ApplicationJob
  queue_as :transcribe


  # If it fails once, the Watchdog will see it as 'failed' 
  # or 'processing' and handle it on the next 2-minute tick.

  def perform(recording_id)
    recording = Recording.find(recording_id)
    TranscriptionService.new(recording).call
  end
end

 
 # => what I want is 
 # 1.add transcrription job to queue. 
 # 2. When the job is complete find the next recording to transcribe  add it to the queue.
 # 3. Have a recurring task checking if the queue is empty if it is,
 # check if there is another recording pending
 
 #clear the queue SolidQueue::Queue.new("transcribe").clear
 # recording 10182. sert to processing for tests
 
 #to clear finished jobs in console
#SolidQueue.clear_finished_jobs_after = 0.seconds
#SolidQueue::Job.clear_finished_in_batches
#SolidQueue::ClaimedExecution.destroy_all