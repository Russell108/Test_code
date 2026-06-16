class Admin::AllowedExtensionsController < ApplicationController
  
  before_action :authenticate_user!
  before_action :authorize_admin  #authorize using format model
  
  def create
    authorize [:admin, @format]
    @allowed_extension = @format.allowed_extensions.new(safe_params)
  #   logger.debug "\n\nsafe_params #{safe_params[:extension_attributes]}\n\n"
    extension = Extension.find_or_initialize_by(safe_params[:extension_attributes])
    @allowed_extension.extension = extension
  #  logger.debug "\n\nextension #{extension.inspect}\n\n"
  #  logger.debug "\n\ncreate #{@allowed_extension.inspect}\n\n"
  #  logger.debug "\n\ncreate #{@allowed_extension.extension.inspect}\n\n"
    @allowed_extension.valid?
  #  logger.debug "\n\nvalid? #{@allowed_extension.errors.full_messages}\n\n"
    if @allowed_extension.save
     redirect_to  edit_admin_format_path(@allowed_extension.format)
    else
      render   :new 
    end
    
  end
  
  def destroy
    logger.debug "\n\n destroy action\n\n"
    logger.debug "\n\n allowed_extension ids #{@format.allowed_extensions.ids}\n\n"
     authorize [:admin, @format]
     @allowed_extension = @format.allowed_extensions.find(params[:id])
     if  @allowed_extension.destroy
        logger.debug "\n\n@format removal}\n\n"
       respond_to do |format|
           format.turbo_stream{render  turbo_stream: turbo_stream.remove("allowed_extension_#{@allowed_extension.id}") }
         end
     else
       respond_to do |format|
         flash.now.alert = error_message_on_delete_to_list(@allowed_extension)
          #logger.debug "\n\n@format centre_format_#{@allowed_extension.id}\n\n"
         format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals:{delay: 5000}) }
       end
     end
  end
  
  private
  
  def authorize_admin
    @format  = Format.find params[:format_id]
  end
  
  
  def safe_params
   
     safe_attributes =[
       
       :extension_attributes=>[:title] 
        ]
      

    params[:allowed_extension]= params.require(:allowed_extension).permit(*safe_attributes)

  end
end
