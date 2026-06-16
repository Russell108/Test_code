class Admin::FormatsController < ApplicationController
  	before_action :authenticate_user!
    
  
  	def index
       
  	   @formats = Format.all.order(:name)
       authorize [:admin, Format]
  	end
    
    def new
      @format = Format.new
      
      authorize [:admin, @format]
    end
    
    def create
      @format = Format.new(create_params)
      authorize [:admin, @format]
   
        if @format.save
          @animate =true
        else
          render   :new 
        end
   
    end
    
    def edit
      @format = Format.find params[:id]
      @allowed_extension = @format.allowed_extensions.build
      @extension = @allowed_extension.build_extension
      authorize [:admin, @format]
      
    end
    
    def update
      @format = Format.find params[:id]
      authorize [:admin, @format]
   
        if @format.update(update_params)
          @animate =true
        else
          render   :edit 
        end
   
    end
    
    def destroy
      @format = Format.find params[:id]
      if @format.destroy
         logger.debug "\n\n@format removal}\n\n"
         respond_to do |format|
           format.turbo_stream{render  turbo_stream: turbo_stream.remove("format_#{@format.id}") }
         
         end
      else
        respond_to do |format|
          flash.now.alert = error_message_on_delete_to_list(@format)
           logger.debug "\n\n@format centre_format_#{@format.id}\n\n"
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals:{delay: 5000}) }
        end
      end
    end
    
    private
    
    def create_params
      safe_attributes = [:name,
                         :purchasable,
                         :packageable,
                         :downloadable]
      params.require(:format).permit(*safe_attributes)
    end
    
    def update_params
      safe_attributes = [:name,
                         :packageable,
                         :purchasable,
                         :downloadable]
      params.require(:format).permit(*safe_attributes)
    end
    
end
