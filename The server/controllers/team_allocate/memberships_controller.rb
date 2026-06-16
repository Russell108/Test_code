class TeamAllocate::MembershipsController < ApplicationController #TeamAllocate::OrdersController
  include CustomerRender
  before_action :authenticate_user! 
  before_action :load_and_authorize 
  
  
  def new
    @group = @happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
    @membership = @happening.memberships.new()
   # respond_to do |format|
   #    format.turbo_stream { render turbo_stream: turbo_stream.replace("membership_for_team", partial: "new") }
   # end
  end
  
  def create
    logger.debug "\n\nTeamAllocate::MembershipsController create"
    mbr_type_id = create_params[:mbr_type_id] rescue nil
    @group = @happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
    results= @group.process_group_membership_application(@happening, create_params[:mbr_type_id])
    flash[:notice]  = results[0]
    flash[:alert]  = results[1]
    redirect_to team_allocate_happening_customers_path(@happening, team2import: params[:team2import])
  end
  
  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  end
 
  
  def create_params
    safe_attributes =[ :mbr_type_id]
    params.require(:membership).permit(*safe_attributes)
  end
end
