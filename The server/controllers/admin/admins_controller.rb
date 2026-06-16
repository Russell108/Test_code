class Admin::AdminsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_centre_and_roles, only: [:index, :show]
  #before_action :turbo_frame_request_variant , only: [ :new]
  
  def index
    authorize Assignment
     @admins = User.order(:surname).with_centre_assignment( current_user.centre_id ).page(params[:page]).per(10)
     @assignment_ids_with_role_id_by_user = policy_scope(Assignment)
     .where(user_id: @admins.collect(&:id), centre_id: current_user.centre.id)
     .assignment_ids_with_role_id_by_user
  end
  
  def show
    @admin = User.find params[:id]
    logger.debug "\n\n@admin #{@admin.inspect}\n\n"
     
    @assignment_ids_with_role_id_by_user = Assignment
    .where(user_id: params[:id], centre_id: current_user.centre.id)
    .assignment_ids_with_role_id_by_user
    
    logger.debug "\n\n@assignment_ids_with_role_id_by_user #{@assignment_ids_with_role_id_by_user.inspect}\n\n"
    @assignment_ids_with_role_id_by_user = {@admin.id => {}} if @assignment_ids_with_role_id_by_user.empty?
  end
  
  def create
    
    redirect_to admin_admin_path(id: params[:user_id])
  end
  
	private
  
  def set_centre_and_roles
    @centre = current_user.centre
		@roles = Role.centre_roles.order(:id)  
  end
  
  def turbo_frame_request_variant
    logger.debug "\n\nturbo_frame_request_variant\n\n"
     request.variant = :turbo_frame if turbo_frame_request?
      logger.debug "\n\nturbo_frame_request_variant #{request.variant}\n\n"
   end

end
