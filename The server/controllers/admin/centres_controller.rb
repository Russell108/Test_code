class Admin::CentresController < ApplicationController
  
	before_action :authenticate_user!
  #CRUD by site admin 
  before_action :set_centre, only: [:show, :edit, :update, :destroy]
	#before_action {(params[:centre] = safe_params)if params[:centre]}

  
  def index
  
    authorize Centre
    @centres = policy_scope(Centre).order("centres.name, formats.id").includes(:bucket, centre_formats: :format).references(:formats)
  end
  
  def show
   
    authorize @centre
    
  end

  def new
     authorize Centre
     @centre = Centre.new()
  end
  
  def create
    @centre = Centre.new(safe_params)
        authorize Centre
    if  @centre.save
    
      #redirect_to admin_centre_centre_formats_path(@centre)
    else
      render "new"
    end
  end

  def edit
    authorize @centre
  end

  def update
     authorize @centre
   
      if @centre.update(safe_params)
        render turbo_stream: turbo_stream.replace("centre_#{@centre.id}", template: "admin/centres/show", locals: {centre: @centre} )
      else
        message = error_message_to_list(@centre)
        logger.debug "\n\n@centre.errors #{message}\n\n"
        flash[:alert] = "Please review.\n There were errors in the form submission."
         render  "edit" 
      end
   
  end

  def destroy
     authorize @centre
      if @centre.destroy
        redirect_to admin_centres_path, status: 303
      else
        respond_to do |format|
          flash.now.alert = error_message_on_delete_to_list(@centre)
           logger.debug "\n\n@centre centre #{@centre.id}\n\n"
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        end
      end
  end
  
  
  
  private
  
  def set_centre
     @centre = Centre.find(params[:id])
  end

  def safe_params
   
     safe_attributes =[
       :name,
       :bucket_id,
       :currency_id,
       :notes,
       :sales_email,
       :centre_formats_attributes=>[:format_id,:id,:max_price, :min_price,:major_rate, :current] 
        ]
      

    params[:centre]= params.require(:centre).permit(*safe_attributes)

  end
  
  
  
end
