class Acquire::AcquiredPackagesController < ApplicationController

    before_action :authenticate_user! 
    before_action :load_and_authorize
  
 
  
  def create
    package = @happening.packages.find(params[:acquired_package][:package_id])
    @acquired_package= package.acquired_packages.new(create_params)
   # @membership.user_id = params[:user_id]
    
        if @acquired_package.save
          redirect_to acquire_happening_acquireship_path(@happening,@acquired_package.user_id )
        else
          respond_to do |format|
             format.turbo_stream {
              flash.now[:alert] ="The package cannot be acquired for the following reasons:<BR><BR>" + (@acquired_package.errors.full_messages.join("<BR>")).html_safe
              render :template => '/shared/flash'
            }
          end
        end
  end
  
	def destroy
    @acquired_package= @happening.acquired_packages.find(params[:id])
		
		if @acquired_package.destroy
      redirect_to acquire_happening_acquireship_path(@happening,@acquired_package.user_id )
     
		else
      respond_to do |format|
         format.turbo_stream {
          flash.now[:alert] ="The package cannot be removed for the following reasons:<BR><BR>" + (@acquired_package.errors.full_messages.join("<BR>")).html_safe
          render :template => '/shared/flash'
        }
      end
		end
  end
  
   private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
    
  end
  
  def create_params
    safe_attributes =[  :user_id, :package_id]
    params.require(:acquired_package).permit(*safe_attributes)
  end
end
