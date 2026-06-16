class Admin::AssignmentsController < ApplicationController
  
  before_action :authenticate_user!
	before_action {(params[:assignment] = safe_params)if params[:assignment]}
  
	#=========================================  restful actions   ===========================================================

 
  def create
   		@assignment= current_user.centre.assignments.new(params[:assignment])
       authorize @assignment
         if @assignment.save
           @animateMe =true
            @assignments = {}
            @assignments[@assignment.role_id] = @assignment.id
           
         else
             flash[:alert] = (@assignment.errors.full_messages.join("<BR>")).html_safe
             render :template => '/shared/flash'
         end 
  end
   
  def destroy
      @assignment= policy_scope(Assignment).find(params[:id])
      authorize @assignment
      if @assignment.destroy
         @animateMe =true
        @assignments = {}
      else
        flash.now.alert = error_message_on_delete_to_list(@assignment)
        render :template => '/shared/flash'
      end
   
  end
  
	#=========================================   private methods   ===========================================================
	private
  
 
	def safe_params
   		safe_attributes =
     		[:user_id,
     		 :role_id
    		 ]
  		params.require(:assignment).permit(*safe_attributes)
 	end
end
