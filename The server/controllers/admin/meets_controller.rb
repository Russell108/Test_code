class Admin::MeetsController < Admin::SuperHappeningsController

  before_action  :load_course, only: [:new, :create]
 
  

  
	def index
    @course =  Course.find( params[:course_id])
    authorize [:admin,  Meet ]
  
    @happenings = @course.happenings.order(title: :desc)
  #  load_recordings_and_speakers(@happenings.collect(&:id))
    
    @active_tab ='Meets'
	end
  
	def show
    
 	#for pdf format find 
  @happening= Meet.find(params[:id])
   @course =  @happening.happenable
   
   authorize [:admin, @happening]
    
     super
	end
  
	def new
    authorize [:admin, Meet]
    logger.debug "\n\n@course #{@course.valid?}\n\n"
    if @course.valid?
      @happening= @course.meets.new
      create_defaults
      logger.debug "\n\n@happening #{@happening.inspect}\n\n"
    else
      flash[:alert] = "The couse deatails need updating before a new meeting can be added."
      redirect_to edit_admin_course_path(@course)
    end
   logger.debug "\n\nrender something for new meet \n\n "
    
  end
  
	def create
    
    authorize [:admin, @course]
    
    @happening= @course.meets.new(create_params)
    @current_creatable_formats = @happening.current_creatable_formats
    if @happening.save
      respond_to do |format|
        format.turbo_stream{render turbo_stream: turbo_stream.replace("new_happening", partial: "create") }
      end
    else
   	logger.debug "\n\n meets controller not saved\n\n"
     render action: :new
    end
	end
  
 	def edit
    
    @happening= Meet.find(params[:id])
    authorize [:admin, @happening]
    @course= @happening.happenable
    super
	end

	def update
    
    @happening= Meet.find(params[:id])
    authorize [:admin, @happening]
    @course= @happening.happenable
    super
	end
  
  
	def destroy
     @happening= Meet.find(params[:id])
    authorize [:admin, @happening]
     @course= @happening.happenable
    if  @happening.destroy
      flash.now[:notice] = ("The meet #{@happening.title} successfully deleted").html_safe
      logger.debug "\n\nredirect_to indsex\n\n"
      redirect_to admin_course_meets_path(@course), status: 303
      
    else
      
      flash.now[:alert] =  ("This #{@happening.type} cannot be deleted, for the following reasons:<BR><BR>" + 
                        @happening.errors.full_messages.join("<BR>")).html_safe
       respond_to do |format|
         format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
       end
    end
	end
  ###############################  private methods  #################################
  private
  
  def create_params
  	return unless params[:happening]
  	(params[:happening][:default_resource_format_ids] = params[:happening][:default_resource_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":default_resource_format_ids") 
    (params[:happening][:default_print_format_ids] = params[:happening][:default_print_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":default_print_format_ids")
  	(params[:happening][:package_format_ids] = params[:happening][:package_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":package_format_ids") 
  	
      safe_attributes =[
        :title,
        :body,
        :venue_id,
        :start_date,
        :end_date,
        :talk_type_id,
        :type,
        {default_resource_format_ids:[]},
        {default_print_format_ids:[]},
        {package_format_ids:[]},
        {default_bundle_ids:[]},
        {bundles_attributes:[:name, format_ids:[]]}]
        
  	params.require(:happening).permit(*safe_attributes) 
  end
  
  # other update params in super_happenings controller
  
  def update_params
  	(params[:happening][:default_resource_format_ids] = params[:happening][:default_resource_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":default_resource_format_ids") 
    (params[:happening][:default_print_format_ids] = params[:happening][:default_print_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":default_print_format_ids")
    	(params[:happening][:package_format_ids] = params[:happening][:package_format_ids].delete_if(&:blank?))if (params[:happening].has_key? ":package_format_ids") 
  		safe_attributes =[
        :title,
        :body,
        :venue_id,
        :start_date,
        :end_date,
        :talk_type_id,
        {default_resource_format_ids:[]},
        {default_print_format_ids:[]},
        {package_format_ids:[]}]
  	params.require(:happening).permit(*safe_attributes)
  end
  
  def  create_defaults
    @current_creatable_formats = @happening.current_creatable_formats
    @happening.talk_type =  @course.talk_type
    @happening.package_formats = @course.default_package_formats
    @happening.default_resource_formats = @course.default_resource_formats
    @happening.default_print_formats = @course.default_resource_formats
    @course.default_bundles.each do |default_bundle|
      attributes={name:default_bundle.name}
      #  (attributes[:purchasable] = true) if( format.purchasable && (["Meet","Event"].include? @happening.type))
      bundle=  @happening.bundles.build(attributes)
      logger.debug "\n\ndefault_bundle #{default_bundle.inspect}\n\n"
       bundle.format_ids =[]
       default_bundle.default_packages.each do |default_package|
         logger.debug "\n\ndefault_package.inspect #{default_package.inspect}\n\n"
        
         bundle.format_ids  << default_package.format_id
       end
        logger.debug "\n\nbundle.format_ids .size #{bundle.format_ids.size}\n\n"
    end
  end
  
  def load_course
    @course =Course.find params[:course_id]
  end
 
end
  
