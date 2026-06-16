class Admin::CentreFormatsController < ApplicationController
  before_action :authenticate_user!
  before_action :initialize_centre

      
  def index
    @centre_formats =  @centre.centre_formats
  end
  
  def new
    @centre_format = @centre.centre_formats.new
  end
  
  def create
    @centre_format = @centre.centre_formats.new(safe_params)
    if  @centre_format.save
    
      #redirect_to admin_centre_centre_formats_path(@centre)
    else
      render "new"
    end
  end
  
  def destroy
    @centre_format = @centre.centre_formats.find params[:id]
    if @centre_format.destroy
       logger.debug "\n\n@centre_format removal}\n\n"
       respond_to do |format|
        # format.turbo_stream{render  turbo_stream: turbo_stream.update("centre_format_#{@centre_format.id}","") }
         format.turbo_stream{render  turbo_stream: turbo_stream.remove("centre_format_#{@centre_format.id}") }
         
       end
    else
      respond_to do |format|
        flash.now.alert = error_message_on_delete_to_list(@centre_format)
         logger.debug "\n\n@centre_format centre_format_#{@centre_format.id}\n\n"
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  

  
  
  
  
  private
  
  def initialize_centre
    @centre= Centre.find(params[:centre_id])
    authorize @centre , :show?
  end
  
  def safe_params
   
     safe_attributes =[
       :format_id,
      ]
    params[:centre_format]= params.require(:centre_format).permit(*safe_attributes)

  end
  
end
