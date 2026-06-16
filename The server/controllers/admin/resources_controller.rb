class Admin::ResourcesController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
 
  
  
  def index
    @resources = @recording.resources.includes(format: :extensions).order("resources.id" )
   
    @new_resources=[]
    default_resource_formats = @happening.default_resource_formats
    potential_format_ids = default_resource_formats.ids - @resources.collect(&:format_id)
    potential_format_ids.each do |format_id|
      new_resource = @recording.resources.new(format_id: format_id)
      @new_resources << new_resource
    end
    logger.debug "\n\n @new_resourcess= #{@new_resources.inspect} \n\n"

  end
  
  def show
    @animate_resource = true
    @resource =  @recording.resources.where(id: params[:id]).first
    respond_to do |format|
      format.turbo_stream{render turbo_stream: turbo_stream.replace("resource_#{@resource.id}", partial: "edit", locals: {resource:@resource} )}   
    end
  end
  
  def new
      
      @resource = @recording.resources.new(talk_type_id: @happening.talk_type_id)
  end

  def create
      @recording=Recording.find params[:recording_id]
      @resource = @recording.resources.new(create_params)
   
      @animate_resource = true
      if @resource.save
        @animate_resource
        respond_to do |format|
          format.html { }
        format.turbo_stream { }
         end
      else
        render action: "new" 
      end
   
  end
  
  def edit
    @resource = @recording.resources.where(id: params[:id])
   
    respond_to do |format|
      format.html   {}
    end
  end
  
  def update
      @resource = @recording.resources.find( params[:id])
      @purchase_credible =  (@resource.format.purchasable && 
                                         CentreFormat.where(centre_id: current_user.centre_id,format_id: @resource.format_id,current: true).any?)
       logger.debug "\n\n@purchase_credible #{@purchase_credible}\n\n"  
       logger.debug "\n\n@resource.purchasable #{@resource.purchasable}\n\n"                                 
   
  
      respond_to do |format|
          if @resource.update(update_params)
            @animate_resource = true
            logger.debug "\n\n @resource.inspect #{ @resource.inspect}\n\n"
            format.turbo_stream {render turbo_stream: turbo_stream.replace("resource_#{@resource.id}", partial: "edit", locals: {resource:@resource} )  }
           
          else
            format.html { render action: "edit" }
          end
      end
  end
  
  
  def destroy
    @resource = @recording.resources.find(params[:id])
    if @resource.destroy
      @animate_resource = true
     respond_to do |format|
       format.html {  }
        format.turbo_stream {render turbo_stream: turbo_stream.remove("resource_#{@resource.id}" )  }
     end
    else
      flash[:alert] =  ("This resource cannot be deleted, for the following reasons:<BR><BR>" + @resource.errors.full_messages.join("<BR>")).html_safe
       respond_to do |format|
         format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals:{delay: 8000}) }
       end
    end
  end
  
   private
   
   
  def load_and_authorize
    @recording =Recording.find params[:recording_id]
    @happening = @recording.happening
    authorize [:admin, @happening], :update?
    
  end
  
  def create_params
      safe_attributes =
          [:format_id,:purchasable,
            :talk_type_id
            ]
      params.require(:resource).permit(*safe_attributes) 
     
     
  end

  def update_params
      safe_attributes =
      [ :purchasable,
        :talk_type_id,
        :file,
        :uploaded,
      ]
    params.require(:resource).permit(*safe_attributes)
  end

  

end
