class Admin::RecordingsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_and_authorize
  before_action :load_resources_search
  
 

  
  def index
    @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happening.id])
     @speakers= Speaker.speakers_for_recordings_render(@grouped_recordings[@happening.id].collect(&:id)) rescue {}
     @active_tab = 'Recordings'
     unless params[:full_page]
      respond_to do |format|
       format.turbo_stream{render  "_index" }
        format.html{ }
      end
    end
  end
  
  def show
    load_recording
    
    @animate_recording =true
     @speakers= Speaker.speakers_for_recordings_render(@recording.id) rescue {}
   #respond_to do |format|
   # format.turbo_stream { render turbo_stream: turbo_stream.replace("recording_#{@recording.id}", partial: "recording", 
   # locals:{recording: @recording, recording_counter:( @recording.number - 1), speakers: @speakers}) }
   #end
  end
  
  def new
      logger.debug "\n\nrequest.headers['Turbo-Frame']=>  #{request.headers["Turbo-Frame"]} <=\n\n"
    @recording = @happening.recordings.new
   @current_purchasable_format_ids = Format.current_by_centre(current_user.centre.id).is_purchasable.ids
   # @form_url ='admin_event_recordings'
    @happening.default_resource_formats.each do|format|
      attributes={format_id:format.id}
      attributes[:talk_type_id] = @happening.talk_type_id
          
     # (attributes[:purchasable] = true) if( format.purchasable && (["Meet","Event"].include? @happening.type))
      resource= @recording.resources.build(attributes)
    end
   
  end
  
  def create
      
    @recording = @happening.recordings.new(create_params)
    @current_purchasable_format_ids = Format.current_by_centre(current_user.centre.id).is_purchasable.ids
 
   @animate_recording = true
      if @recording.save
        respond_to do |format|
          format.html {  }
          format.turbo_stream {  }
        end
      else
      
        render action: "new" 
     
      end
   
     
  end

  def edit
    load_recording
  end
 
  def update
    load_recording
   # @speakers= Speaker.speakers_for_recordings_render(@recording.id) rescue {}
    respond_to do |format|
      if @recording.update(update_params)
       format.turbo_stream{ redirect_to admin_happening_recording_path(@happening, @recording), scrollTo: true, animate:true}
      
      else
        format.html { render action: "edit" }
      end
    end
  end
 
  def destroy
    load_recording
    if @recording.destroy
      respond_to do |format|
        format.html {  }
        format.turbo_stream{ render turbo_stream: turbo_stream.replace("recording_#{@recording.id}", partial: "recording",
         locals:{recording: @recording, happening: @happening, recording_counter:( @recording.number - 1)} ) }
      end
    else
      respond_to do |format|
        logger.debug "\n\n@recording errors #{@recording.errors.full_messages}\n\n"
        flash.now[:alert] = error_message_on_delete_to_list(@recording)
        format.turbo_stream{render  template: "admin/recordings/destroy_errors" }
      end
    end
  end
 
 
 
 #. other methods
 private
 
 def load_and_authorize
   @happening= Happening.find(params[:happening_id])
   @course = @happening.happenable if (@happening.type =="Meet")
   authorize [:admin, @happening], :update?
   @recording_admin = true
 end
  
  def load_recording
   @recording = @happening.recordings.find( params[:id])
  end
  
  
  def load_resources_search
    @resource_search=ResourceSearch.new(params[:resource_search]) 
    @resource_search.page = params[:page]
  end
 
 def create_params
     return unless params[:recording]
     
     safe_attributes =[
             :title,
             :duration,
             :start_datetime,
             :writeup,
             resources_attributes: [:purchasable,:format_id, :talk_type_id]
         ]
     
     params.require(:recording).permit(*safe_attributes) 
 end

 def update_params
     return {} unless params[:recording]
     safe_attributes =[
             :title,
             :duration,
             :start_datetime,
             :writeup,
             resources_attributes: [:purchasable,:format_id, :talk_type_id]
         ]
     
     params.require(:recording).permit(*safe_attributes)
 end
 
 
end
