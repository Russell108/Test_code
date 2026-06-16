module AdminAcquisitionRender
  extend ActiveSupport::Concern

  def load_collections_for_team_acquisition_render(happening,current_user,team2render)
    logger.debug "\n\nteam2render #{team2render}\n\n"
    attachable = (happening.type=="Meet") ? happening.course : happening
    @attached_group = attachable.attached_groups.find_by(user_id: current_user.id) rescue nil
    if( team2render== "acquirees")
      @acquirers ||= User.acquireships_for_happening(@happening.id).distinct
     
    elsif( team2render== "group")
      @acquirers = User.joins(:group_memberships).where("group_memberships.group_id =?", @attached_group.group_id)
    end
    @acquirers =@acquirers.user_search_limit_search_to_2_strings(params[:people_search])
                .order(Arel.sql("users.surname ")).page(params[:page])
    user_ids = @acquirers.collect(&:id) 
     logger.debug "\n\n user_ids #{user_ids}\n\n"
    load_collections_for_acquisition_render(user_ids, happening)
  end
  
  def load_collections_for_acquisition_render(user_ids, happening)
    @recordings = happening.recordings.order("recordings.number").pluck("recordings.id, recordings.title").to_h
    load_package_collections_for_acquisition_render(user_ids, happening.id)
    load_resource_collections_for_acquisition_render(user_ids, happening.id)
  end
  
  def load_collections_for_user_acquisitions_render(user_id, happening_ids)
    logger.debug "\n\nload_collections_for_user_acquisitions_render \n\n"
    @recordings = Recording.where(happening_id: happening_ids)
    .group("recordings.happening_id")
    .pluck(Arel.sql("recordings.happening_id, array_agg(array[recordings.id, recordings.number])")).to_h
    @packages =   Package.acquireable_plucked_by_happening(happening_ids).to_h
    @acquired_packages = Package.joins(:acquired_packages)
        .where("acquired_packages.user_id in (?) and packages.happening_id in (?)", user_id, happening_ids )
        .pluck("packages.id, acquired_packages.order_id").to_h
    @acquired_resources = Resource.joins(:acquired_resources, :recording)
        .where("acquired_resources.user_id in (?) and recordings.happening_id in (?)", user_id, happening_ids )
        .pluck("resources.id, acquired_resources.order_id").to_h
   @resources = Resource.where("recordings.happening_id in (?)", happening_ids )
    .joins(:format, :recording)
    .group("resources.recording_id")
    .pluck(Arel.sql("resources.recording_id, array_agg(array[resources.id::text, formats.name::text]) ")).to_h
   #logger.debug "\n\n @resources #{@resources}\n\n"
  end
  
  def load_package_collections_for_acquisition_render (user_ids, happening_ids)
    @acquired_packages_by_user = Package.happening_acquired_packages_by_user(user_ids, happening_ids).to_h
    @packages =   Package.acquireable_plucked_by_happening(happening_ids).to_h
  end

  def load_resource_collections_for_acquisition_render (user_ids, happening_id)
    @resources =   Resource.acquireable_plucked_by_happening(happening_id) 
    @acquired_resources_by_user= Resource.happening_acquired_resources_by_user(user_ids, @happening.id).to_h
  end
  

end