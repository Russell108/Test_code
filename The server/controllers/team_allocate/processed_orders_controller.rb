class TeamAllocate::ProcessedOrdersController < TeamAllocate::OrdersController
  include CustomerRender
   before_action :authenticate_user!
   before_action :load_and_authorize  
   
   def create
   
      @controller_first_namespace ="team_allocate"
    
     if @happening.type =="Meet"
        @group = @happening.course.attached_groups.find_by(user_id: current_user.id).group rescue nil
     else
        @group = @happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
     end
     controller_first_namespace ="team_allocate"
     team_to_manage = @happening.users_4_team_import(params[:team2import],@group)
     @orders= @happening.carts.where(user_id: team_to_manage.ids )
     checkout_result =  @happening.checkout_carts(@orders)
     success_message =checkout_result[0]
     error_message =checkout_result[1]
    #logger.debug "error_message,inspect #{error_message,inspect}"
   
    flash[:notice] = success_message.size.to_s + " " +  ((success_message.size > 1) ? "orders" : "order") +
     " " + "successfully processed for:<BR>".html_safe + success_message.join("<BR>")
     ( flash[:alert] = error_message.size.to_s + ' order'.pluralize(error_message.size) + " not processed for the following " + "reasons<BR>" +  error_message.join("<BR>"))unless error_message.blank?
     redirect_to team_allocate_happening_customers_path(@happening, team2import: params[:team2import])
   end
   
   def load_and_authorize
     @happening= Happening.find(params[:happening_id])
     authorize [:admin, @happening], :update?
   end
end
