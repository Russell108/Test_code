class JobReceipt < ApplicationRecord
  
  enum :status, { 
    received: 0, 
    preparing: 1, 
    prepared: 2,
    processing: 3, 
    completed: 4, 
    failed: 5 
  }
  
  
  
  

    has_many :transcription_logs, dependent: :destroy
    has_many :wav_chunks, dependent: :destroy
    


    
    
    def log_status(message)
      # 1. Force everything to string with interpolation
      safe_cage = "#{ENV['QUEUES'] == 'transcription_heavy' ? 'MUSCLE' : 'SYSTEM'}"
      safe_msg  = "#{message}"

      # 2. Use a block to catch the EXACT error during the save
      begin
        new_log = transcription_logs.create!(message: "[#{safe_cage}] #{safe_msg}")

      
      rescue => e
        # This will tell us if the DB is rejecting the string
        puts "!!! LOG_STATUS INTERNAL ERROR: #{e.message}"
        Rails.logger.error "log_status error: #{e.message}"
      end
    end
    
    private
 
end
