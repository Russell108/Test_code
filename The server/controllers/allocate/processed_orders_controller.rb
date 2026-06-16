class Allocate::ProcessedOrdersController < ApplicationController
 
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  def create
    sleep 5
     @orders= @happening.carts
    checkout_result =  @happening.checkout_carts(@orders)
    success_message =checkout_result[0]
    error_message =checkout_result[1]
   #logger.debug "error_message,inspect #{error_message,inspect}"
   
   flash[:notice] = success_message.size.to_s + " " +  ((success_message.size > 1) ? "orders" : "order") +
    " " + "successfully processed for:<BR>".html_safe + success_message.join("<BR>")
    ( flash[:alert] = error_message.size.to_s + " " +  'order'.pluralize(error_message.size) +
    " " + "unprocessed for:<BR>".html_safe +
                  error_message.join("<BR>"))unless error_message.blank?
    
      redirect_to allocate_happening_customers_path(@happening, team2import: "customers")
    
  end
  
  
  def update
    logger.debug "\n\n process oder for a single customer\n\n"
    @orders = @happening.carts.where(id: params[:id])
    @order= @orders.first
    checkout_result =  @happening.checkout_carts(@orders)
    success_message =checkout_result[0]
    error_message =checkout_result[1]
   flash[:notice] = success_message.size.to_s + " " +  ((success_message.size > 1) ? "orders" : "order") +
    " " + "successfully processed for:<BR>".html_safe + success_message.join("<BR>")
   ( flash[:alert] = error_message.join("<BR>"))unless error_message.blank?
    @user = @order.user
     logger.debug "\n\n start redirect to customers show\n\n"
    redirect_to allocate_happening_customer_path(@happening,  id: @order.user_id, 
    team2import: params[:team2import] ),:status => 303
  end
  
  
  def destroy
    @order = ProcessedOrder.find params[:id]
    @order.destroy
   
  end
  
  
  
  
  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  end
  
end
