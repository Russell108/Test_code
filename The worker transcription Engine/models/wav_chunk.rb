class WavChunk < ApplicationRecord
  belongs_to :job_receipt
  
  enum :status, { 
    pending: 0, 
    running: 1, 
    completed: 2, 
    failed: 3 
  }
  
end
