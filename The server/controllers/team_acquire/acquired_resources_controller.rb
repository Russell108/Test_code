class TeamAcquire::AcquiredResourcesController < TeamAcquire::AcquireshipsController
  
    before_action :authenticate_user! 
  
  
  
  def create
    @controller_first_namespace ||="team_acquire"
    group = @happening.group_for_user(current_user)       
    import_result =  @happening.add_acquired_resource_to_group_import_members( create_params,group)
    
    load_collections_for_team_acquisition_render( @happening, current_user,'group')
     flash.now[:notice] = "#{import_result[0]} #{"resource".pluralize(import_result[0])  } added to groups members"
     flash.now[:alert] = import_result[1].join("<BR>")
    
    render :index
  end
  
  def destroy
    logger.debug "\n\nparams=> #{params[:id]}\n\n"
    acquired_resources = AcquiredResource.where(resource_id: params[:id], order_id: nil)
    purchased_resources_size =  AcquiredResource.where(resource_id: params[:id]).where.not( order_id: nil).size
    size_of_acquired_resources = acquired_resources.size
    if acquired_resources.delete_all
      notice =""
      if (size_of_acquired_resources ==0)
        notice  << " No resources removed "
      else
        notice  << "successfully removed #{size_of_acquired_resources} acquired resources " 
        flash.now[:notice] = "successfully removed #{size_of_acquired_resources} acquired resources" 
      end
   
     notice <<  "<BR>#{purchased_resources_size.to_s} purchased #{"resource".pluralize purchased_resources_size} untouched"
     flash.now[:notice] = notice
    end
    load_collections_for_team_acquisition_render( @happening, current_user,'group')
    render :index
  end
  
  def create_params
    safe_attributes =  [:resource_id]
    params.require(:acquired_resource).permit(*safe_attributes)
  end
end
