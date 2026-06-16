class Admin::Users::OrdersController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :load_and_authorize
  def index
     @active_tab = 'Orders'
    @orders = @user.orders.includes(:happening).references(:happening)
              .where(type:['ProcessedOrder'])
              
    if !params[:happening_id].blank?
      @orders = @orders.where("happenings.id= ?", params[:happening_id])
    else
      @orders = @orders.where("happenings.title ILIKE ?", "%#{params[:search]}%") if !params[:search].blank?
    end
    @orders = @orders.order(["orders.type ASC", "orders.happening_id DESC"]).page(params[:page]).per(5)
    load_bundles_and_resources(@user.id, @orders.ids)
    @administerable_happening_ids = administerable_orders(@orders)
   
      respond_to do |format|
         format.turbo_stream{ }
         format.html{render template: "acquire/users/show" }
      end
   
  end
  
  
  def destroy
    
  end
  
  private
  
  def load_bundles_and_resources(user_id, order_ids)
    @ordered_bundles   = OrderItem.ordered_bundles_by_user_by_order_ids_grouped_by_order(user_id, order_ids)
    @ordered_resources = OrderItem.ordered_resources_by_user_by_order_ids_grouped_by_order(user_id, order_ids)
  end
  
  def administerable_orders (orders)
    centre_id = current_user.centre_id
    happening_ids = orders.collect(&:happening_id)
    administerable_happening_ids =[]
    
    # Public     role id 3   happening type Event  or Meet
    # Garthering role id 4   happening type  gathering
    # Project    role id 5   happening type project
    
    administerable_happening_ids = Happening.where(id: happening_ids).left_outer_joins([{centre: :assignments},:protected_admins])
    .where("(centres.id =? and assignments.user_id =? and happenings.protected is false and (\n
    (assignments.role_id =3 and  happenings.type ='Event') OR \n
    (assignments.role_id =5 and  happenings.type ='Project') OR 
    (assignments.role_id =4 and  happenings.type ='Gathering'))) OR \n
    (protected_admins.user_id =?)", centre_id, current_user.id, current_user.id).distinct.ids
   
    course_administerable_happening_ids = Meet.where(id: happening_ids).left_outer_joins(course:[{centre: :assignments},:protected_admins])
    .where("(centres.id =? and assignments.user_id =? and assignments.role_id = 3) OR \n
     ( protected_admins.user_id =?)", centre_id, current_user.id, current_user.id).distinct.ids

    administerable_happening_ids.concat course_administerable_happening_ids

   return administerable_happening_ids.uniq
  end
  
  def load_and_authorize
    @user =User.find params[:user_id]
    authorize [:admin, Happening], :index?
  end
end
