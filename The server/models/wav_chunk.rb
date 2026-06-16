class WavChunk < ApplicationRecord
  # This links the 300s chunk back to the main job
  belongs_to :recording

  # Statuses for the 4-core worker (Worker A)
  # 0: pending, 1: running, 2: completed, 3: failed
  enum :status, { 
    pending: 0, 
    running: 1, 
    completed: 2, 
    failed: 3 
  }

end
