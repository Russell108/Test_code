class Transcription::RecordingsController < ApplicationController
   before_action :authenticate_user!
   before_action {(params[:resource_search] = safe_search_params)if params[:resource_search]}
  # before_action  :load_resources_search, only: :index                                          #[:index, :show]
   

   
#  def index
#    authorize [:transcription, Recording]
#    @search_title= 'Happening Search'
#    @search_url = "transcription_recordings_url"
#    @resource_search.transcription_status ||= "requested"
#    @recordings =  @resource_search.recordings#.where.not(priority: nil )
#    .includes({resources: :format}, {contributions: :speaker}, :happening)
#    .order(priority: :desc, happening_id: :desc)
#    .page(params[:page]).per(50)
#
#
#    @failed_transcriptions = Recording.failed
#    recording_ids = @recordings.map(&:id)
#    @grouped_recordings= @recordings.to_a.group_by(&:priority).transform_values { |recs| recs.group_by(&:happening) } 
#    @grouped_speakers = Speaker.speakers_for_render_group_by_happening(recording_ids)
#   
#  end
   
   def show
     @recording = Recording.find( params[:id])
      authorize [:transcription, @recording]
    @grouped_speakers = Speaker.speakers_for_render_group_by_happening(@recording.id)
    @animate= params[:animate] == "true"
    logger.debug "\n\n@recording.transcription_status #{@recording.transcription_status}\n\n"
   end
   
   def edit
     @recording = Recording.find params[:id]
      authorize [:transcription, @recording]
   end
   
   def update
     @recording = Recording.find params[:id]
     @recording.editable_when_locked =  ["transcription_status","priority","transcribed_at"]
     logger.debug "\n\neditable_when_locked\n\n"
      authorize [:transcription, @recording]
      @recording.transcribed_at= Time.now
      @recording.attributes = recording_params
      logger.debug "\n\n  #{@recording.transcription_status} #{@recording.changed}\n\n"
      if @recording.update(recording_params)
        flash[:success] =" Recordings Updated"
        redirect_to transcription_recording_path(@recording, animate: true ), status: :see_other
      else
        # Re-render 'edit' form with validation errors (status 422 is best practice)
        render :edit, status: :unprocessable_entity
      end
      
   end
   
   def destroy
      @recording = Recording.find params[:id]
     if @recording.remove_raw_transcript
       @grouped_speakers = Speaker.speakers_for_render_group_by_happening(@recording.id)
       @animate= "true"
       respond_to do |format|
         format.html {  }
         format.turbo_stream{ }
       end
     else
       respond_to do |format|
         logger.debug "\n\n@recording errors #{@recording.errors.full_messages}\n\n"
         flash.now[:alert] = error_message_on_purge_transcription(@recording)
         format.turbo_stream{render  template: "admin/recordings/destroy_errors" }
       end
     end
   end
 
   
   private
   
   def load_resources_search
     # logger.debug "\n\nlinitialize new resource Admin::SuperHappeningsController\n\n"
     @resource_search=ResourceSearch.new(params[:resource_search]) 
     @resource_search.recording_policy_scope = policy_scope([:transcription, Recording])
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
   		:end_date,
      :transcription_status
   	]
  
     params[:resource_search]= params.require(:resource_search).permit(*safe_attributes)
  
   end
   
   def recording_params
     allowed_fields = [:priority, :transcription_status]
   #  allowed_fields << :raw_transcript if @recording&.transcription_status == "completed"
      params.require(:recording).permit(allowed_fields)
    end
   
   
  
end
