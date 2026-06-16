class Allocate::OrderItemsController < Allocate::OrdersController
 # include CustomerRender
  
 
  private

  

  def create
    logger.debug "\n\nhello world create\n\n"
    @order_item = @order.order_items.new(safe_params)
    
    if @order_item.save
      super
    else
       respond_to do |format|
          format.html { render action: "new" }
          format.js {  flash[:error] =  ("#{(@order_item.orderable_type  )} cannot be added, for the following reasons:<BR><BR>" +
                     @order_item.errors.full_messages.join("<BR>")).html_safe
          
          render :template => '/shared/errors.js.erb' }
        end
    end
    
  end
  
 def destroy
   logger.debug "\n\nhello world destroy\n\n"
    @order = @happening.orders.find params[:cart_id]
    @order_item = @order.order_items.find params[:id]

    if @order_item.destroy
      super
    else
      flash[:error] =  ("This bundle cannot be deleted, for the following reasons:<BR><BR>" + @bundle.errors.full_messages.join("<BR>")).html_safe
       render :template => '/shared/errors.js.erb'
    end
  end
  
  

  
  def safe_params
    safe_attributes =  [:orderable_type, :orderable_id]
    params.require(:order_item).permit(*safe_attributes)
  end
  

  
  def load_assets
  end
  

  
end
