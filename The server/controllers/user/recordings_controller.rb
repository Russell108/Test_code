class User::RecordingsController < ApplicationController
  before_action :authenticate_user! 
 # before_action :load_and_authorize
# before_action :set_active_tab
 
 
#  def index
#   @happening =Happening.find(params[:event_id])
#    scope_to_view = policy_scope([:user, Resource]).where("recordings.happening_id =?", @happening.id)
#
#    
#    @resource_search=ResourceSearch.new(safe_search_params) 
#    @resource_search.resource_policy_scope=scope_to_view
#
#    @grouped_resources = @resource_search.resources.group_by{|resource|resource.recording_id}
#     
#     load_recordings_and_speakers
#     logger.debug "\n\n@ recordings #{@recordings.size}\n\n"
#  end
  def index
    @happening_id = params[:event_id]
    scope_to_view = policy_scope([:user, Resource]).where("recordings.happening_id = ?", @happening_id)

    @resource_search = ResourceSearch.new(safe_search_params) 
    @resource_search.resource_policy_scope = scope_to_view
    @grouped_resources = @resource_search.resources.group_by { |resource| resource.recording_id }
    
    respond_to do |format|
      if @grouped_resources.any?
        load_recordings_and_speakers
        
        format.html # renders index.html.erb normally
        format.turbo_stream # renders index.turbo_stream.erb if using streams, or you can let the frame capture below handle it
      else
        # Force these to be empty arrays so the view's speaker loops don't crash on nil
        @recordings = []
        @speakers = []
        
        format.html
        format.turbo_stream { render :index } # Re-use the index view to render the friendly fallback inside the turbo-frame
      end
    end
  end
  
  def show
    @recording = Recording.find(params[:recording_id])
    
  end
  
  private
  
  def set_active_tab
    @active_tab = "Recordings"
  end
  
#  def load_and_authorize
#    @happening = policy_scope([:user, Happening]).find(params[:event_id])
#  
#  end
 
  def load_recordings_and_speakers
    @recordings = Recording.where(id: @grouped_resources.keys).order(number: :asc)
    
    @speakers = Speaker.speakers_for_recordings_render(@grouped_resources.keys.uniq)
    
    logger.debug "\n\n@ speakers #{@speakers.inspect}\n\n"
  	@page_no = params[:page].blank? ? 1: params[:page].to_i
  	@total_pages= @happenings.total_pages rescue nil
  end 
  
	def safe_search_params
    return {} unless( params.has_key? :resource_search)
		safe_attributes =[
			 :speaker_id,
			:start_date,
			:end_date
		]
	  params[:resource_search]= params.require(:resource_search).permit(*safe_attributes)
	end
 
end
