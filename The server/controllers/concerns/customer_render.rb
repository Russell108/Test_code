# app/controllers/concerns/your_controller_concern.rb
module CustomerRender
  extend ActiveSupport::Concern


    def load_collections_for_team_allocation_render(happening,current_user, team2import, people_string =nil)
      #attachable = (happening.type=="Meet") ? happening.course : happening
      @attached_group = happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
      @users=  happening.users_4_team_import(team2import, @attached_group) 
      
      @users = @users
      .user_search_limit_search_to_2_strings(people_string)
      .order('users.surname').page(params[:page])
       load_collections_for_customer_allocation_render(happening, @users,team2import)  
    end
  
  def load_collections_for_customer_allocation_render(happening, users,  team2import)  
    #logger.debug "\n\n happening #{happening.inspect}\n"
    #logger.debug "users #{users.inspect}"
    logger.debug "\n\n CustomerRender team2import #{team2import.inspect}\n\n"
    
     user_ids = users.collect(&:id) # @customers outcome of load_customer_collections
   # logger.debug "\n\nuser_ids #{user_ids}\n\n"
    @recordings = Recording.where(happening_id: happening.id )
    .left_outer_joins(:resources)
    .order("recordings.number")
    .pluck("recordings.id, recordings.title").to_h
    if(happening.type =="Meet")
      @memberships_by_user_ids = happening.course.memberships.where(user_id:user_ids ).map{|m|[m.user_id, m]}.to_h
      @registrations_by_user_ids = happening.registrations.joins(:membership)
      .where("memberships.user_id in (?)",user_ids )
      .pluck("memberships.user_id, registrations.id").to_h
    else
      @memberships_by_user_ids = happening.memberships.where(user_id:user_ids ).map{|m|[m.user_id, m]}.to_h
  
    end
     logger.debug "\n\n@memberships_by_user_ids #{@memberships_by_user_ids}\n\n"
    @valid_customer_user_ids = user_ids
    @cart_ids_by_user= happening.carts.where("orders.user_id in (?)",user_ids).pluck(Arel.sql("user_id, id ")).to_h
    @resources = Resource.purchasable_plucked_by_happening(happening.id).to_h
    
     logger.debug "\n\n @resources #{@resources.inspect}\n\n"
    
    @team2import =team2import
    @carted_bundles_by_user = OrderItem.bundle_cart_items_plucked_and_grouped_by_user(happening.id,user_ids)
    @purchased_bundles_by_user = OrderItem.purchased_order_items_plucked_and_grouped_by_user( happening.id,user_ids, "Bundle").to_h
    @acquired_packages_by_user = Package.happening_acquired_packages_by_user(user_ids, happening.id).to_h
    @cart_resources_by_user = Resource.plucked_happening_carted_resources_by_user(user_ids, happening.id)  
    @carted_bundled_package_formats_by_user = Package.carted_bundled_package_formats_by_user(user_ids, happening.id).to_h
    @acquired_resources_by_user= Resource.happening_acquired_resources_by_user(user_ids, @happening.id).to_h 
    logger.debug "\n@team2import #{@team2import.inspect}"
    logger.debug "@purchased_bundles_by_user #{@purchased_bundles_by_user.inspect}"
    logger.debug "@acquired_packages_by_user #{@acquired_packages_by_user.inspect}"
    logger.debug "@cart_resources_by_user #{@cart_resources_by_user.inspect}"
    logger.debug "@carted_bundled_package_formats_by_user #{@carted_bundled_package_formats_by_user.inspect}"
    logger.debug "@acquired_resources_by_user #{@acquired_resources_by_user.inspect}\n"
  end
end