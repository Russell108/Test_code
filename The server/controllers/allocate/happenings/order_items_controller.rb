class Allocate::Happenings::OrderItemsController < ApplicationController
 
  before_action :authenticate_user!
  before_action :load_and_authorize
  
  
  def create
   order = @happening.carts.find_or_create_by(user_id: params[:user_id] )
    if order.valid?
      order_item =order.order_items.new(safe_params)
      if order_item.save
        redirect_to allocate_happening_customer_path( id: order.user_id, happening_id: @happening.id, team2import: params[:team2import], animate: true  )
      else
        flash.now[:alert] = (order_item.errors.full_messages.join("<BR>")).html_safe
        render :template => '/shared/flash'
      end
    else
      flash.now[:alert] = (order.errors.full_messages.join("<BR>")).html_safe
      render :template => '/shared/flash'
      return
    end
    
  end
  
  def destroy
   # logger.debug "\n\nhello world destroy\n\n"
     @order_item = OrderItem.find params[:id]
    
     if @order_item.destroy
       redirect_to allocate_happening_customer_path( id: params[:user_id], happening_id: @happening.id, team2import: params[:team2import], animate: true ),
       status: 303
     else
       respond_to do |format|
          format.turbo_stream {
           flash[:alert] = (@order_item.errors.full_messages.join("<BR>")).html_safe
           render :template => '/shared/flash'
         }
       end
     end
   end
  
 
  
  ###############################.   private.   ########################################
  private
  
  def safe_params
    safe_attributes =  [:orderable_type, :orderable_id]
    params.require(:order_item).permit(*safe_attributes)
  end

  def load_and_authorize
     
    @happening= Happening.find( params[:happening_id])
    authorize [:admin, @happening], :update?
  end  
  
end
