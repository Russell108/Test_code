class TeamAllocate::OrderItemsController < TeamAllocate::OrdersController
 include CustomerRender
  before_action :authenticate_user!
  before_action :load_and_authorize

  
  def create
    group = @happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
   # logger.debug "\n\nTeamAllocate::OrderItemsController  line 13\n\n"
    import_result =  @happening.add_order_item_to_team_import(params[:team2import], create_params, group)
   # logger.debug "\n\nTeamAllocate::OrderItemsController  line 15\n\n"
    logger.debug "\n\nimport_result #{import_result[1]}\n\n"
    errors =import_result[1].join("<BR>").html_safe rescue nil
  #  logger.debug "\n\nerrors #{errors}\n\n"
    flash[:notice]  = import_result[0]
    flash[:alert]  = import_result[1]
    redirect_to team_allocate_happening_customers_path(  happening_id: @happening.id, team2import: params[:team2import] )
    
  end
  
 
  
   private
  
  def create_params
  	safe_attributes =[
  		:orderable_id,
      :orderable_type
  	]
  
    params[:order_item]= params.require(:order_item).permit(*safe_attributes)
  
  end
end

