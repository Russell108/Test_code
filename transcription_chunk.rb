class TranscriptionChunk < ApplicationRecord
  # This links the 300s chunk back to the main job
  belongs_to :transcription_job

  # Statuses for the 4-core worker (Worker A)
  # 0: pending, 1: running, 2: completed, 3: failed
  enum :status, { 
    pending: 0, 
    running: 1, 
    completed: 2, 
    failed: 3 
  }

  # Helper to find the next chunk for the 4-core worker
  scope :ready_to_transcribe, -> { where(status: :pending).order(:start_time) }
end
