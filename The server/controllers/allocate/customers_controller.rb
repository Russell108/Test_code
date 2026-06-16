class Allocate::CustomersController < ApplicationController
  include CustomerRender
  before_action :authenticate_user! 
  before_action :load_and_authorize
  before_action :set_index_params, only: :index

  
  def index
    params[:team2import] ||=  "customers"
    load_collections_for_team_allocation_render(@happening, current_user, params[:team2import], params[:people_search]) 
    @active_tab = 'customers'
    case params[:team2import]
      when "All Course", "Current Course", "Guest Course", "Tutor Course", "Student Course", "Lapsed Course"
          
        @team_process_label = params[:team2import] + ' members'
      when "All", "Current", "Guest", "Tutor", "Student", "Lapsed"
        @team_process_label = params[:team2import] + ( (@happening.type == 'Meet') ? ' registrations' : ' members')
      when "customers"
        @team_process_label = 'all customers'
      when "group"
        @team_process_label = 'group members'
      else
        @team_process_label = ""
    end
      logger.debug "\n\n@users.size #{@users.size}\n\n"
  end
  
  def create
     @animate = (params.has_key? :animate) ?  true : false
    @user =User.find params[:user_id]
    load_collections_for_customer_allocation_render(@happening, [@user], params[:team2import])
     logger.debug "\n\n@animate= #{@animate}\n\n"
  end
  
  def show
    @user=User.find params[:id]
    @animate = (params.has_key? :animate) ?  true : false
    load_collections_for_customer_allocation_render(@happening, [@user], params[:team2import])
    @remove_after_animate = true  unless ( @memberships_by_user_ids.has_key?(@user.id) || @cart_ids_by_user.has_key?(@user.id)) 
     logger.debug "\n\n@animate= #{@animate}\n\n"
    respond_to do |format|
       format.turbo_stream { }
       format.html{ }
    end
  end
  
  private
  
  
  def set_index_params
    @search_params_4_pagination = {team2import:  params[:team2import] ,  people_search: params[:people_search] } rescue {}
    
    logger.debug "\n\n@search_params_4_pagination #{@search_params_4_pagination}\n\n"
  end
  
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    @course = @happening.happenable if (@happening.type == "Meet")
    authorize [:admin, @happening], :update?
  end
end
