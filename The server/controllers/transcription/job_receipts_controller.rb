class Transcription::JobReceiptsController < ApplicationController
  before_action :authenticate_user!
  
  
  def index
  #  authorize [:transcription, JobReceipt]
   
    @failed_recording_transcriptions = Recording.failed.size
    
    @actively_transcribing_recordings = Recording
    .by_transcription_status([:dispatched, :received, :preparing, :prepared, :processing, :processed ])
                   
    @job_receipts =JobReceipt.includes(:recording)
                  .order(id: :desc)
                  .page(params[:page]).per(15)
   
  end
  
  
end
