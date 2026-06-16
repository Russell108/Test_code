class Transcription::CoursesController < Admin::CoursesController
  #authenticate_user!  in poarent controller
 skip_before_action  :authorize_and_Load_course
  
  def index
     authorize [:transcription, Course]
     @courses = policy_scope([:transcription, Course]).includes(:meets)   #@courses = policy_scope([:transcription, Course).includes(:meets)
     @courses = @courses.order(start_date: :desc) 
         .includes(:default_resource_formats)#, :print_formats, :default_packages)
         .left_outer_joins(:talk_type)
         .page(params[:page])
         (@courses = @courses.text_search(params[:search]) )unless params[:search].blank?
  end
  
  def show
    @course = Course.find params[:id]
    authorize [:transcription, @course]
    @happenings = @course.meets.includes(:venue)
    logger.debug "\n\nare we here \n\n"
    @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happenings.ids])
    @grouped_resources = Resource.joins(:recording)
    .where('recordings.happening_id in(?)', @happenings.ids ).group_by{|resource|resource.recording_id}
    @grouped_speakers = Speaker.speakers_for_render_group_by_happening(Recording.where(happening_id: @happenings.ids ).ids)
   
  end
  
  def edit
    @course = Course.find params[:id]
     authorize [:transcription, @course]
  end
  
  def update
    @course = Course.find params[:id]
     authorize [:transcription, @course]
    
      logger.debug "\n\ncourse_params #{course_params} \n\n"
     
     recordings_added_to_transcription_service = @course.add_recordings_to_transcription_service(course_params)
         
    if  recordings_added_to_transcription_service 
      flash[:alert] ="#{recordings_added_to_transcription_service} Recordings added to transcription queue"
      respond_to do |format|
        format.html {  }
        format.turbo_stream { redirect_to transcription_course_path(@course) }
      end
      
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  private
  
  def course_params
    params.expect(course: [
      :priority,
      :reset_failed_transcription ,
      :reset_pending_transcription,
      :ignore_currently_requested_transcription
    ])
  end
  
  
  
end
