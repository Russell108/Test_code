class Import::GroupsController < ApplicationController
   before_action :authenticate_user! 
  
  
  

  def update
    authorize User
    
    @group =Group.find(params[:id])
    if (@group.update(update_params) and  @group.import.attached?)
      respond_to do |format|
        format.turbo_stream {redirect_to import_group_group_memberships_path(@group) }
      end
    else
      logger.debug "\n\n update error\n\n"
      flash.now.alert = "Please choose a CSV " #unless( params.has_key? :import)
      respond_to do |format|
        format.turbo_stream{ }
      end
    end
   
  end
  
  
  
  private
  def update_params
 safe_attributes =
   [ :import,
     :delete_import,
     :remove_emails,
     :check_in
   ]
    
   params.require(:group).permit(*safe_attributes) rescue {}
  end
end
