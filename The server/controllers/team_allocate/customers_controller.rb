class TeamAllocate::CustomersController < ApplicationController
  include CustomerRender
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  
  
  def index
    load_collections_for_team_allocation_render(@happening, current_user, params[:team2import], params[:people_search]) 
     @active_tab = 'customers'
    @controller_first_namespace ="team_allocate"
    case params[:team2import]
      when "All Course", "Current Course", "Guest Course", "Tutor Course", "Student Course", "Lapsed Course"
        @team_process_label = params[:team2import] + ' members'
      when "All", "Current", "Guest", "Tutor", "Student", "Lapsed"
        @team_process_label = params[:team2import] + ( (@happening.type == 'Meet') ? ' registrations' : ' members')
      when "customers"
        @team_process_label = 'customers'
      when "group"
        @team_process_label = 'group members'
      else
        @team_process_label = ""
    end
    logger.debug "\n\n@users.size #{@users.size}\n\n"
  end
  
  def create
    @user =User.find params[:user_id]
    load_collections_for_customer_allocation_render(@happening, [@user], params[:team2import])
  end

  
  def show
    @user=User.find params[:id]
    load_collections_for_customer_allocation_render(@happening, [@user], params[:team2import])
    respond_to do |format|
       format.turbo_stream {  }
    end
  end

  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    @course = @happening.happenable if (@happening.type == "Meet")
    authorize [:admin, @happening], :update?
  end
end
