class Acquire::AcquiredResourcesController < ApplicationController

  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  def create
    @acquired_resource= AcquiredResource.new(create_params)

    
        if @acquired_resource.save
          redirect_to acquire_happening_acquireship_path(@happening,@acquired_resource.user_id )
        else
          logger.debug 
          respond_to do |format|
             format.turbo_stream {
              flash.now[:alert] ="The resource cannot be acquired for the following reasons:<BR><BR>" + (@acquired_resource.errors.full_messages.join("<BR>")).html_safe
              render :template => '/shared/flash'
            }
          end
        end
   
  end
  
  
  def destroy
    @acquired_resource= @happening.acquired_resources.find(params[:id])
		
		if @acquired_resource.destroy
      redirect_to acquire_happening_acquireship_path(@happening,@acquired_resource.user_id )
		else
      respond_to do |format|
         format.turbo_stream {
          flash.now[:alert] ="The resource cannot be acquired for the following reasons:<BR><BR>" + (@acquired_resource.errors.full_messages.join("<BR>")).html_safe
          render :template => '/shared/flash'
        }
      end
		end
  end
    
################################################################################################################

  private   ################################################################
      
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
    
  end
  
  
 	def create_params
    safe_attributes =[  :user_id,
                        :resource_id]
    params.require(:acquired_resource).permit(*safe_attributes)
  end
end
