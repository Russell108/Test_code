class Admin::Reorder::RecordingsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  def update
   # @recording = @happening.recordings.find( params[:id])
   result =  Recording.reorder_sessions(@happening.id, params[:id], update_params[:number])
    logger.debug "\n\nresult #{result.inspect}"
   
    result2= Recording.update(result[0], result[1])
    logger.debug "\n\nresult2 #{result2.inspect}"
  end
  
  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
   # @course = @happening.happenable if (@happening.type =="Meet")
    authorize [:admin, @happening], :update?
  #  @recording_admin = true
  end
  
  def update_params
      return {} unless params[:recording]
      safe_attributes =[
              :number
          ]
     
      params.require(:recording).permit(*safe_attributes)
  end
end
