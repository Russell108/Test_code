class Admin::Courses::DefaultBundlesController < ApplicationController
    
  before_action :authenticate_user! 
  before_action :load_and_authorize_course
 
  
  def new
    @default_bundle = @course.default_bundles.new
    @current_creatable_formats =@course_default_formats = Format.current_by_centre(current_user.centre_id) 
  end
  
  def edit
    @default_bundle = @course.default_bundles.find(params[:id])
    @current_creatable_formats =@course_default_formats = Format.current_by_centre(current_user.centre_id) 
  end
  
  def create
    @default_bundle = @course.default_bundles.new(safe_params)
    @animate_default_bundle = true
    if @default_bundle.save
      respond_to do |format|
        format.turbo_stream { }
      end
    else
      @current_creatable_formats =@course_default_formats = Format.current_by_centre(current_user.centre_id) 
        render action: "new"
    end
  end
  
  def update
    @default_bundle = @course.default_bundles.find(params[:id])
    @animate_default_bundle = true
      if @default_bundle.update(safe_params)
         respond_to do |format|
           format.turbo_stream { render turbo_stream: turbo_stream.replace("default_bundle_#{@default_bundle.id}", @default_bundle) }
         end                   
      else
        @current_creatable_formats =@course_default_formats = Format.current_by_centre(current_user.centre_id) 
        render action: "edit"
      end
    
  end
  
  def destroy
     @default_bundle = @course.default_bundles.find(params[:id])
     @animate_default_bundle = true
     if @default_bundle.destroy
       respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace("default_bundle_#{@default_bundle.id}", @default_bundle) }
       end
     else
       flash.now[:alert] =  ("This bundle cannot be deleted, for the following reasons:<BR><BR>" + @default_bundle.errors.full_messages.join("<BR>")).html_safe
        render :template => "shared/flash"
     end
  end
  
  ###############################.   private.   ########################################
  private
  

  def load_and_authorize_course
    @course= Course.find(params[:course_id])
    authorize [:admin, @course], :update?
 
  end
  
  
  def safe_params
    (params[:default_bundle][:default_package_format_ids] = params[:default_bundle][:default_package_format_ids].delete_if(&:blank?)) if( params[:default_bundle].has_key? "default_package_format_ids")
    
    safe_attributes =  [:name,
                        :price,
                      {default_package_format_ids:[]}]
    params.require(:default_bundle).permit(*safe_attributes)
  end
end
