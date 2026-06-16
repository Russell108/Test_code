class Allocate::CartsController < ApplicationController
  include CustomerRender
  before_action :authenticate_user! 
  before_action :load_and_authorize

  def new
    @user=User.find params[:user_id]
    @animate_customer = true
    load_collections_for_customer_allocation_render(@happening, [@user], params[:team2import])
    respond_to do |format|
       format.turbo_stream { }
    end
  end
  
  def destroy
    @cart =@happening.carts.find params[:id]
    if  @cart.destroy
       redirect_to allocate_happening_customer_path( id: @cart.user_id, happening_id: @happening.id, team2import: params[:team2import]),
       status: 303
    else
        flash.now[:alert] =  ("This order cannot be deleted, for the following reasons:<BR><BR>" + 
                          @cart.errors.full_messages.join("<BR>")).html_safe
        render :template => '/shared/flash'
    end        
  end
  
  private

 	def create_params
    safe_attributes =[ :user_id]
    params.require(:cart).permit(*safe_attributes)
  end

  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  
  end
  
  
end
