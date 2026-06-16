class Admin::SuperHappeningsController < ApplicationController
  before_action :authenticate_user! 
  before_action {(params[:resource_search] = safe_search_params)if params[:resource_search]}
  before_action  :load_resources_search, only: [:index, :show]
  


  

 
  
  def index
    logger.debug "\n\nparams #{params.inspect}\n\n"
    @offcanvas_title = controller_name.titleize + " Search"
    @resource_search.happening_policy_scope ||= Happening.none
    @happenings = @resource_search.happenings.includes(:venue)
    @happenings= @happenings.page(params[:page])
    @search_url = "admin_#{controller_name.downcase}_url"
		(flash.now[:alert] = "Your search returned no recordings. Please widen your search criteria")if( params[:resource_search] and @happenings.empty?)
    @safe_search_params = {resource_search: params[:resource_search] }rescue {}
    logger.debug "\n\n@safe_search_params #{@safe_search_params}\n\n"
  end
  
  
	def show
    # we load reasource search for showing search
    @customer_search_placeholder ="Search all with an order"
    @grouped_resources = Resource.joins(:recording)
    .where('recordings.happening_id =?', @happening.id ).group_by{|resource|resource.recording_id}
    load_attached_collections_for_render([@happening.id])
    @active_tab = 'Details'
    @scroll_to_value = "happening_#{@happening.id}"
		logger.debug"\n\nsuper happenings show self.request.format we will now render #{self.request.format}\n\n"
    if (self.request.path_parameters[:format] == "pdf")
     respond_to do |format|
       format.pdf do
       #	if( ["Meet", "Event"].include? @happening.type)
       		 @recordings=@happening.recordings
       	 			.where("recordings.duration >0")
       	 			.joins(:resources)
       	 			.includes( contributions: :speaker,resources:[:format])
       	 			.order("recordings.number ASC")
       	 			.distinct
       #	 end
           pdf= SessionListPdf.new(@happening,@recordings, params[:with_prices])
           send_data  pdf.render, filename: "session list #{@happening.id}", type:"application/pdf",disposition: "inline"
       end
     end
   end
   
	end
  
	def new
		@current_creatable_formats = @happening.current_creatable_formats
  end
  
	def create
    @current_creatable_formats = @happening.current_creatable_formats
    @happening.current_user_id = current_user.id 
    @happening.packages.each do |package|
    end
    @active_tab = 0
    respond_to do |format|
      if @happening.save
        format.turbo_stream{render turbo_stream: turbo_stream.replace("new_happening", partial: "create") }
      else
    		logger.debug "\n\nnot saved\n\n"
          format.turbo_stream{render turbo_stream: turbo_stream.replace("new_happening", template: "admin/super_happenings/new") }
         # format.turbo_stream {render action: "new"}
        
      end
		end
	end
  
 	def edit
    
		@current_creatable_formats = Format.current_by_centre(current_user.centre_id)
		 #respond_to do |format|
		 #  format.html {}
		 #  format.turbo_stream{render turbo_stream: turbo_stream.replace("happening_#{@happening.id}", template: "admin/super_happenings/edit") }
     # 
     #end
	end
  
	def update
  @happening.current_user_id = current_user.id
	  
	    if @happening.update(update_params)
         @active_tab = 'Details'
         redirect_to send("admin_#{@happening.type.downcase}_path", @happening)
      # # load_recordings_and_speakers([@happening])
      #   format.html { }
      #  format.turbo_stream {}
	    else
        respond_to do |format|
          @current_creatable_formats = Format.current_by_centre(current_user.centre_id)
          format.html { render action: "edit" }
        end
	    end
	  
	end
  
	def destroy
	    if  @happening.destroy
        flash[:alert] = ("The #{@happening.type} #{@happening.title} successfully deleted").html_safe
	      redirect_to send("admin_#{@happening.type.downcase}s_path"), status: 303
	    else
        flash.now[:alert] =  ("This #{@happening.type} cannot be deleted, for the following reasons:<BR><BR>" + 
        @happening.errors.full_messages.join("<BR>")).html_safe
        respond_to do |format|
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }     
        end  
        flash.clear
                    
	    end  
	end
  
  
   private
  
  #######################################################################################
  
  def load_resources_search
    # logger.debug "\n\nlinitialize new resource Admin::SuperHappeningsController\n\n"
    @resource_search=ResourceSearch.new(params[:resource_search]) 
    @resource_search.page = params[:page]
  end
  

  def load_attached_collections_for_render(happening_ids)
    @no_animation = true 
    @bundled_packages = BundleItem.bundle_packages_hashed_and_plucked_by_bundle_ids(happening_ids)
    @bundled_resources = BundleItem.bundle_resources_hashed_and_plucked_by_bundle_ids(happening_ids) 
    
  end
 
  def safe_search_params
    logger.debug "params[:resource_search] = #{params[:resource_search]}"
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
  



  
end
