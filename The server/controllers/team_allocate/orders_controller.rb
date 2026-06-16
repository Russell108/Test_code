class TeamAllocate::OrdersController < ApplicationController
    include CustomerRender
   before_action :authenticate_user! 
   before_action :load_and_authorize
  def index
    load_collections_for_team_allocation_render(@happening, current_user, params[:team2import], params[:people_search]) 
    
    @controller_first_namespace ="team_allocate"
    case params[:team2import]
      when "All Course", "Current Course", "Guest Course", "Tutor Course", "Student Course", "Lapsed Course"
        @team_process_label = params[:team2import] + ' members'
      when "All", "Current", "Guest", "Tutor", "Student", "Lapsed"
        @team_process_label = params[:team2import] + ( (@happening.type == 'Meet') ? ' registrations' : ' members')
      when "carts"
        @team_process_label = 'all'
      when "group"
        @team_process_label = 'group members'
      else
        @team_process_label = ""
    end
    respond_to do |format|
       format.turbo_stream{render turbo_stream: turbo_stream.replace("happening_sales", partial: "index" ) }
       format.html{ }
    end
   
  end
  
  private
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  end
 
  
end
