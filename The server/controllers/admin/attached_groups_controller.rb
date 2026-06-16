class Admin::AttachedGroupsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  

  def create
    @attached_group= @happening.attached_groups.find_or_initialize_by(user_id: current_user.id)
    @attached_group.group_id = create_params[:group_id]
      if @attached_group.save
        logger.debug "\n\nredirect_to admin_#{@happening.type.downcase}_path)\n\n"
           redirect_to send("admin_#{@happening.type.downcase}_path", @happening)
           
      else
        respond_to do |format|
          format.html { render action: "new" }
          flash.now[:alert] =  (@attached_group.errors.full_messages.join("<BR>")).html_safe
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        end
      end
  end
  
  def destroy
    @attached_group= current_user.attached_groups.find(params[:id])
    
    if @attached_group.destroy
      logger.debug"\n\ndestroy  Admin::AttachedGroupsController\n\n"
      respond_to do |format|
        format.html { }
        format.turbo_stream { logger.debug"\n\nturbo destroy  Admin::AttachedGroupsController\n\n"
          redirect_to send("admin_#{@happening.type.downcase}_path", @happening)}
      end
    else
      flash.now[:alert] =  (@attached_group.errors.full_messages.join("<BR>")).html_safe
      respond_to do |format|
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  
  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  end
  
  
  def create_params
  	
    safe_attributes =[
      :group_id
    ]
  	params.require(:attached_group).permit(*safe_attributes) 
  end
  
end
