class LocksController < ApplicationController
  
  before_action :authenticate_user!
	def create
    
    logger.debug"\n\redirect_to_path #{params[:redirect_to_path]}\n\n"
		@lock = Lock.new(safe_params)
    authorize @lock  
		 unless @lock.save
        flash[:notice] = "Unable to lock."
		  end
	   # redirect_back(fallback_location: root_path)
     redirect_to params[:redirect_to_path]
 	end
  
  def destroy
    
    logger.debug "\n\n redirect_to_path #{params[:redirect_to_path]}\n\n"
    @lock=Lock.find(params[:id])
    authorize @lock
    unless @lock.destroy
        flash[:alert] =  ("Unable to unlock").html_safe
    end
     redirect_to params[:redirect_to_path]
   end
  
  private
  
  

  
	def safe_params
		safe_attributes =[:lockable_type,:lockable_id]
		params.require(:lock).permit(*safe_attributes)
 	end
  
 		
end
