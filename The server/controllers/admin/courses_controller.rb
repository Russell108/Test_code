class Admin::CoursesController < ApplicationController 
 # authorize every action in child controllers
  before_action :authenticate_user!
  before_action :authorize_and_Load_course, only:[ :show,:edit, :update, :destroy]
   

   
  def index
    authorize [:admin, Course]
    @courses = policy_scope([:admin, Course]).includes(:meets)
    @courses = @courses.order(start_date: :desc)
        .includes(:default_resource_formats)#, :print_formats, :default_packages)
        .left_outer_joins(:talk_type)
        .page(params[:page])
        (@courses = @courses.text_search(params[:search]) )unless params[:search].blank?
  end
  
  def show
     @active_tab ="Details"
  end
  
  def new
    @course = Course.new
     authorize [:admin, @course]
     @formats_available_for_centre  = Format.current_by_centre(current_user.centre_id)
 
  end

  def create
   
    @course = current_user.centre.courses.new(safe_params)
     authorize [:admin, @course]
    @course.current_user_id = current_user.id
    @formats_available_for_centre = Format.current_by_centre(current_user.centre_id)
    respond_to do |format|
      if @course.save
      #  @course =Course.left_outer_joins(:talk_type).select("courses.*, talk_types.name AS talk_type_name").find(@course.id)
        format.html {  }
        format.turbo_stream {logger.debug "\n\n some thing here\n\n"
          render turbo_stream: turbo_stream.replace("new_course", partial: "create")  }
      else
        flash.now[:alert] =  (@course.errors.full_messages.join(", ")).html_safe
        format.html { render action: "new" }
      end
    end
  end
  
  def edit
    @formats_available_for_centre = Format.current_by_centre(current_user.centre_id)
    @course.valid?
    respond_to do |format|
      format.html 
    end
  end
  
  def update
   @course.current_user_id = current_user.id
      if @course.update(safe_params)
        redirect_to admin_course_path @course
      else
        respond_to do |format|
          @formats_available_for_centre = Format.current_by_centre(current_user.centre_id)
          @course_default_resources = @course.default_resources
          format.html { render action: "edit" }
        end
      end
  end
  
  def destroy
      if  @course.destroy
          logger.debug "\n\n @course.destroy \n\n"
          redirect_to admin_courses_path#, status: 303
      else
        respond_to do |format|
          flash.now[:alert] = error_message_on_delete_to_list(@course)
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        end
      end
  end
  
  
  private
  
  def authorize_and_Load_course
    @course = Course.find params[:id]
   authorize [:admin, @course]
  end
  
  def safe_params
    (params[:course][:default_resource_format_ids] = params[:course][:default_resource_format_ids].delete_if(&:blank?)) if( params[:course].has_key? "default_resource_format_ids")
    (params[:course][:default_package_format_ids] = params[:course][:default_package_format_ids].delete_if(&:blank?)) if( params[:course].has_key? "default_package_format_ids")
   
   		safe_attributes =
   		  [:title,
          :protected,
         :sub_title,
         :notes,
         :start_date,
         :end_date,
         :talk_type_id, 
         :sales_scope_id,
        {default_resource_format_ids:[]},
        {default_package_format_ids:[]}]
   		params.require(:course).permit(*safe_attributes)
  end
  
  
  

end
