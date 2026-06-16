class Admin::ProjectsController <  Admin::SuperHappeningsController
    before_action :authenticate_user! 
  
	def index
     logger.debug "\n\n index action Admin::ProjectsController\n\n"
      @search_title= 'Projects Search'
    authorize [:admin, Project]
    @resource_search_url= admin_projects_url()
    @resource_search.happening_policy_scope = policy_scope([:admin, Project])
    #logger.debug "\n\n@resource_search.happening_policy_scope  #{@resource_search.happening_policy_scope.inspect }\n\n"
    super
	end
  

  
	def show
		#for pdf format find 
    @happening= Project.find(params[:id])
    authorize [:admin, @happening]
    super
	end
  
  
	def new
    @happening= current_user.centre.projects.new
   # @happening.happenable = current_user.centre
     authorize [:admin,  Project]
    
      super
    end
  
	def create
    @happening= current_user.centre.projects.new(create_params)
    authorize [:admin, Project]
    super
	end
  
 	def edit
    @happening= policy_scope([:admin, Project]).find(params[:id])
    authorize [:admin, @happening]
     
    super
	end

	def update
    @happening= policy_scope([:admin, Project]).find(params[:id])
    authorize [:admin, @happening]
    super
	end
  
	def destroy
    @happening= policy_scope([:admin, Project]).find(params[:id])
    authorize [:admin, @happening]
	  
    super
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
         :sales_scope_id,
        :protected,
        {default_resource_format_ids:[]},
        {default_print_format_ids:[]},
        {package_format_ids:[]}]
  	params.require(:happening).permit(*safe_attributes) 
  end
  
  # other update params in super_happenings controller
  def update_params
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
         :sales_scope_id,
         :protected,
        :stream_id,
        {default_resource_format_ids:[]},
        {default_print_format_ids:[]},
        {package_format_ids:[]},
        :document]
  	params.require(:happening).permit(*safe_attributes) 
  end
  



end
