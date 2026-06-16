 class Admin::BundlesController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :load_and_authorize
  before_action :set_scroll_to_value, only: [:create,  :update] #:show,
  

  
  def new
     @bundle = @happening.bundles.new
  
  end
  
  def create
    @bundle = @happening.bundles.new(safe_params)
    
      if @bundle.save
        respond_to do |format|
          load_bundleable_items
           @animate =true
          
          format.turbo_stream { }
         end
      else
      render action: "new" 
      end
   
  end
  
  
  def edit
    
     load_bundleable_items
     load_collections_for_recordings
    
  end
  
  def update
    respond_to do |format|
      if @bundle.update(safe_params)
        logger.debug("\n\nsafe_params = #{safe_params}\n\n")
         @animate =true
        load_bundleable_items
        format.turbo_stream{ render turbo_stream: turbo_stream.replace("bundle_#{@bundle.id}", @bundle ) }
        
      else
        load_bundleable_items
        load_collections_for_recordings
         logger.debug "\n\n not saved\n\n"
        flash[:alert] = " Please review.There were errors in the form submission."
        format.turbo_stream {render turbo_stream: turbo_stream.update("bundle_#{@bundle.id}",  partial: "edit")   }
      end
    end
  end
  
 
  def destroy

    if @bundle.destroy
      respond_to do |format|
         load_bundleable_items
        format.html {  }
         format.turbo_stream { }
      end
    else
      flash.now.alert = error_message_on_delete_to_list(@bundle)
      format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
    end
  end
  
  
  
 
  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
   # @recording_admin = true
    @bundle = @happening.bundles.find( params[:id] ) if params[:id]
    @recording_admin =true
    @scroll_to_value =  @happening
  end

  
  def load_bundleable_items
    @bundled_packages = BundleItem.bundle_packages_hashed_and_plucked_by_bundle_ids([@happening.id])
    @bundled_resources = BundleItem.bundle_resources_hashed_and_plucked_by_bundle_ids([@happening.id])
  end
  
  def load_collections_for_recordings
    @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happening.id])
  #  logger.debug "\n\n.@grouped_recordings #{@grouped_recordings.inspect} \n\n"
  end
  
  def set_scroll_to_value
    @scroll_to_value = "happening_#{@happening.id}"
    logger.debug "\n\n@scroll_to_value #{@scroll_to_value}\n\n"
  end
  
  def safe_params
    return {} unless params[:bundle]
  	(params[:bundle][:package_ids] = params[:bundle][:package_ids].delete_if(&:blank?))if (params[:bundle].has_key? ":package_ids") 
    
    safe_attributes =  [:name,
                        :price,
                         {package_ids:[]}]
    params.require(:bundle).permit(*safe_attributes)
  
  end
end

