class Admin::GatheringsController <  Admin::SuperHappeningsController
  # hello russell
  # hello from air
  
  
	def index
    @search_title= 'Gathering Search'
    authorize [:admin, Gathering]
    @resource_search_url= admin_gatherings_url()
    @resource_search.happening_policy_scope = policy_scope([:admin, Gathering])
    super
	end
  

  
  
  
  
	def show
		#for pdf format find 
    @happening= Gathering.find(params[:id])
    authorize [:admin, @happening]
    super
	end
  
  
	def new
    @happening= current_user.centre.gatherings.new
   # @happening.happenable = current_user.centre
     authorize [:admin,  Gathering]
    
    
    super
  end
  
	def create
    @happening= current_user.centre.gatherings.new(create_params)
    authorize [:admin, Gathering]
    super
	end
  
 	def edit
    @happening= policy_scope([:admin, Gathering]).find(params[:id])
    authorize [:admin, @happening]
     
    super
	end

	def update
    @happening= policy_scope([:admin, Gathering]).find(params[:id])
    authorize [:admin, @happening]
    super
	end
  
	def destroy
    @happening= policy_scope([:admin, Gathering]).find(params[:id])
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
        :protected,
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
        :protected,
        :venue_id,
        :start_date,
        :end_date,
        :talk_type_id,
        :sales_scope_id,
        :stream_id,
        :protected,
        {default_resource_format_ids:[]},
        {default_print_format_ids:[]},
        {package_format_ids:[]},
        :document]
  	params.require(:happening).permit(*safe_attributes) 
  end
  


end
