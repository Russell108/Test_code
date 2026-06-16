class JobReceipt < ApplicationRecord
  
  
   ###############################   relationships  ######################################
  belongs_to :recording

  
  enum :status, { 
    completed: 0, 
    failed: 1 
  }
  
  ###############################   callbacks  ######################################
  
  after_create_commit :broadcast_to_monitor
 
  ###############################   scope  ######################################
  
  scope :by_status, ->(status) { where(status: status) }  
 
  ###############################   public methods  ######################################

 


  ###############################   private methods  ######################################
  private
  
  def finalized?
    # Only purge if the job reached a terminal state
    completed? || failed?
  end



  def broadcast_to_monitor
    # 1. Prepend the new row to the table
    broadcast_prepend_to(
      "transcription_monitor_channel",
      target: "historical_jobs",
      partial: "transcription/job_receipts/job_receipt",
      locals: {job_receipt: self }
    )
  end
  
end
