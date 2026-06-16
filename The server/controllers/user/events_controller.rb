class User::EventsController <  ApplicationController
  before_action :authenticate_user!
  before_action {(params[:resource_search] = safe_search_params)if params[:resource_search]}
  before_action  :load_resources_search, only: [:index, :show]


 
  def index
   # @accessable_stream_happening_ids = []
    @resource_search.happening_policy_scope =  policy_scope([:user, Happening])
    @resource_search.page = params[:page]
    @search_url = "events_url"
    @happenings =  @resource_search.happenings.page(params[:page])
    
  	(flash.now[:alert] = "Your search returned no recordings. Please widen your search criteria")if( params[:resource_search] and @happenings.empty?)
    @safe_search_params = {resource_search: params[:resource_search] }rescue {}
    
    logger.debug "\n\n@happenings size #{@happenings.size} \n\n"
  end
  
  def show
     @happening =  Happening.find params[:id]
    @resource_search=ResourceSearch.new()
     @resource_search.happening_id = params[:id]
    @resource_search.happening_policy_scope =  policy_scope([:user, Happening])
    
     @search_url = "events_url" 
    
    if (self.request.path_parameters[:format] == "pdf")
      #need to get stuff
      load_resources_for_recordings
      respond_to do |format|
        format.pdf do
          pdf= UserSessionListPdf.new(@happening,@recordings,@grouped_resources)
          send_data  pdf.render, filename: "#{@happening.title} (#{@happening.id})", type:"application/pdf",disposition: "inline"
        end
      end
    end
  end
  
	private
  
  rescue_from ActiveRecord::RecordNotUnique do |exception|

    message= ("<H3>A Duplicate record already exists. </H3> 
          <p>Please refresh the page & try again.</p>").html_safe
      respond_to do |format|
        format.html { flash[:alert] = message
                    redirect_to root_path}
      end
    
  end
 
 
  rescue_from ActiveRecord::RecordNotFound do |exception|
    logger.debug "\n\nuser/events controller rescue_from ActiveRecord::RecordNotFound do |exception|\n\n"
      message = ("
            <p>Currently the item you requested is not available.<BR>
              If you think it should be please let us know us at \"support (at) drusound.com \" .</p>").html_safe
      respond_to do |format|
        format.html { flash[:alert]= message
             redirect_to(action: :index)}
        format.turbo_stream {flash.now[:alert]= message
            render :template => '/shared/flash'}
        format.pdf {flash[:alert]= message
              redirect_to(action: :index)}
      end
  
  end
  
  def set_referrer
    request.env['HTTP_REFERER'] ||= "https://six.local/events"
  end
  

  
  def load_resources_search
   # logger.debug "\n\nlinitialize new resource Admin::SuperHappeningsController\n\n"
    @resource_search=ResourceSearch.new(params[:resource_search]) 
    @resource_search.page = params[:page]
  end
  
	def safe_search_params
    return if params[:resource_search].blank?
	 
		safe_attributes =[
			:text_search,
			:digest_id,
			:happening_id,
			:speaker_id,
			:start_date,
			:end_date
		]

	  params[:resource_search]= params.require(:resource_search).permit(*safe_attributes)

	end
  
  def dude_wheres_my_record
    render partial: "user/streams/errors", :layout => false
  end
  
  def load_stream(happening)
    @stream ||=policy_scope([:user, Stream]).where("streams.happening_id =? and streams.end_time >= ?", happening.id , 10.minutes.ago).first
    @accessable_stream_happening_ids = @stream.blank? ? [] : [@stream.happening_id]
   
    return  if @active_tab
    if (@stream.blank? )
      @active_tab = "Recordings"
    else
       @active_tab = "Stream"
    end
    
  end
  
  def load_resources_for_recordings
    @resources = policy_scope([:user, Resource]).where('recordings.happening_id =?',@happening.id ).distinct
    @grouped_resources = @resources.group_by{|resource|resource.recording_id}
    
    @recordings = Recording.where(id: @grouped_resources.keys)
    @speakers = Speaker.speakers_for_recordings_render(@grouped_resources.keys.uniq)
  end
end
