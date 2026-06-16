class TeamAcquire::AcquiredPackagesController < TeamAcquire::AcquireshipsController
   before_action :authenticate_user! 
  
  
  
  
  def create
    @controller_first_namespace ||="team_acquire"
    group = @happening.group_for_user(current_user)  
    import_result =  @happening.add_acquired_package_to_group_import_members( create_params,group)
    
    load_collections_for_team_acquisition_render( @happening, current_user,'group')
     flash.now[:notice] = "#{import_result[0]} #{"package".pluralize(import_result[0])  } added to groups members"
     flash.now[:alert] = import_result[1].join("<BR>")
    
    render :index
  end
  
  def destroy
    logger.debug "\n\nparams=> #{params[:id]}\n\n"
    acquired_packages = AcquiredPackage.where(package_id: params[:id], order_id: nil)
    purchased_packages_size =  AcquiredPackage.where(package_id: params[:id]).where.not( order_id: nil).size
    size_of_acquired_packages = acquired_packages.size
    if acquired_packages.delete_all
      flash.now[:notice] = ("successfully removed #{size_of_acquired_packages} acquired packages + <BR>" +
                            purchased_packages_size.to_s + " purchased packages kept")
    end
    logger.debug "\n\n acquired_packages=> #{acquired_packages.size}\n\n"
    load_collections_for_team_acquisition_render( @happening, current_user,'group')
    render :index
  end
  
  def create_params
    safe_attributes =  [:package_id]
    params.require(:acquired_package).permit(*safe_attributes)
  end
end