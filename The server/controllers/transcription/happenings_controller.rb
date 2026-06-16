class Transcription::HappeningsController < ApplicationController
  
  before_action :authenticate_user!
  before_action {(params[:resource_search] = safe_search_params)if params[:resource_search]}
  before_action  :load_resources_search, only: [:index, :show]
    def index
         # 1. Extract the ID from the nested params
         happening_id = safe_search_params&.dig( :happening_id )

         # 2. Redirect if the ID is present
         if happening_id.present?
           return redirect_to transcription_happening_path(happening_id)
         end
       authorize [:transcription, Happening]
       @search_title= 'Happening Search'
     #  @resource_search.page = params[:page]
       @resource_search_url= transcription_happenings_url()
       @search_url = "transcription_happenings_url"
        @happenings =  @resource_search.happenings.includes(:venue, {recordings: {resources: :format}}).page(params[:page])
        happening_ids = @happenings.map(&:id)
        recording_ids = Recording.where(happening_id: happening_ids).ids
      @grouped_speakers = Speaker.speakers_for_render_group_by_happening(recording_ids)
 
 
 
 
  # @resource_search.happening_policy_scope = policy_scope([:admin, Happening])
    end
   
   def show
     @happening = Happening.find params[:id]
     authorize [:transcription, @happening]
     @search_title= 'Happening Search'
     @resource_search_url= transcription_happenings_url()
     @search_url = "transcription_happenings_url"
      @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happening.id])
      recording_ids =  Recording.where(happening_id: @happening.id).ids
       @grouped_speakers = Speaker.speakers_for_render_group_by_happening(recording_ids)
       @grouped_resources = Resource.joins(:recording)
      .where('recordings.happening_id =?', @happening.id ).group_by{|resource|resource.recording_id}

   end
#  
   def edit
     @happening = Happening.find params[:id]
      authorize [:transcription, @happening]
   end
#  
   def update
     @happening = Happening.find params[:id]
      authorize [:transcription, @happening]
    
      #@course.priority = 5
     
      recordings_added_to_transcription_service = @happening.add_recordings_to_transcription_service(happening_params)
         
     if  recordings_added_to_transcription_service 
       flash[:alert] ="#{recordings_added_to_transcription_service} Recordings added to transcription queue"
       redirect_to transcription_happening_path(@happening ), status: :see_other
     else
       render :edit, status: :unprocessable_entity
     end
   end
  
   private
  
   def happening_params
     params.expect(happening: [
       :priority,
       :reset_failed_transcription ,
       :reset_pending_transcription,
       :ignore_currently_requested_transcription
     ])
   end
  
   private
  
  #######################################################################################
  
  def load_resources_search
    # logger.debug "\n\nlinitialize new resource Admin::SuperHappeningsController\n\n"
    @resource_search=ResourceSearch.new(params[:resource_search]) 
    @resource_search.happening_policy_scope = policy_scope([:transcription, Happening])
    @resource_search.page = params[:page]
  end
  

  def load_attached_collections_for_render(happening_ids)
    @no_animation = true 
    @bundled_packages = BundleItem.bundle_packages_hashed_and_plucked_by_bundle_ids(happening_ids)
    @bundled_resources = BundleItem.bundle_resources_hashed_and_plucked_by_bundle_ids(happening_ids) 
    
  end
 
  def safe_search_params
    logger.debug "\n\n transcription  params[:resource_search] = #{params[:resource_search]} \n\n"
    return if params[:resource_search].blank?
  	safe_attributes =[
  		:text_search,
  		:digest_id,
  		:happening_id,
  		:speaker_id,
  		:start_date,
  		:end_date,
      :transcription_status
  	]
  
    params[:resource_search]= params.require(:resource_search).permit(*safe_attributes)
  
  end
   

   
   
end
