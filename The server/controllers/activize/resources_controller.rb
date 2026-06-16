class Activize::ResourcesController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
 
 
  
  
  def update
    @resource = @recording.resources.where(id: params[:id]).first                
    respond_to do |format|
        logger.debug("\n\nhello\n\n")
      if @resource.update(update_params)
         logger.debug("\n\nadmin/recordings/resource_btn\n\n")
        @animate_resource_btn =true
        format.turbo_stream {render turbo_stream: turbo_stream.replace("resource_btn_#{@resource.id}",
        partial: "admin/recordings/resource_btn", locals: {resource:@resource, recording: @recording} )  }
       
      else
        
        flash.now[:alert] =  ("This resource cannot be confirmed as Uploaded, for the following reasons:<BR><BR>" +
                         @resource.errors.full_messages.join("<BR>")).html_safe
        format.html { }
       format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
      end
    end
  end
  
   private
   
  def load_and_authorize
    @recording = Recording.find params[:recording_id]
    @happening = @recording.happening
    authorize [:admin, @happening], :update?
  end
  
  def update_params
      safe_attributes =
      [ :uploaded,
       ]
    params.require(:resource).permit(*safe_attributes)
  end
  
  
end
