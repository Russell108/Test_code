class CurrentCentre::AdminController < ApplicationController
  before_action :authenticate_user!
  
  
  def edit
    flash.discard
    respond_to do |format|
      format.html {}
      format.turbo_stream{render turbo_stream: turbo_stream.replace("yield_content", template: "/current_centre/admin/edit")   }
    end

  end
  
  def update
    flash.discard
    if   current_user.update(update_params)
      current_user.reload
      redirect_to root_path
    else
      render action: "edit"
    end
    

  end
  
 
  
  
  private

  
  def update_params
    safe_attributes =
    	[:centre_id
       ]
    params.require(:user).permit(*safe_attributes)
  end
end
