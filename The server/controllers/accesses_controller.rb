class AccessesController < ApplicationController
   before_action :authenticate_user!
  
    # before_action :safe_params, :only => [:create, :update]
    # manage accesses for Talk types self referencing relationship 
    # CRUD site admin
  




	def create
     @access= Access.new(create_params)
     authorize @access
        if @access.save
          respond_to do |format|
            format.turbo_stream {}
          end
        else
          respond_to do |format|
            flash.now[:alert] = (@access.errors.full_messages.join("<BR>")).html_safe
             format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
          end
        end 
	end

	def destroy
    @access = Access.find(params[:id])
    authorize @access
		if @access.destroy
     		 
		else
			flash.now[:alert] =  ("This access cannot be deleted, for the following reasons:<BR><BR>" + @access.errors.full_messages.join("<BR>")).html_safe
			  # flash[:alert] = "You are not permitted to delete this User. 
			  #                  You can remove all their Assignments for your centre.
			  #                  They have admin roles assigned for other centres. 
			  #                  Please contact support if you need further clarity or assistance 'support@drusound.com'"
      respond_to do |format|
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
      end
		end
	end

private
	# ====================================   private methods==========================================================================

	def create_params
		
  		safe_attributes =[
  		:access_type_id,
  		:talk_type_id]
 		
		params.require(:access).permit(*safe_attributes)
	end


end
