class Admin::PackagesController < ApplicationController
  
  before_action :authenticate_user! 
  before_action :load_and_authorize

  
  def new
    @package = @happening.packages.new
    respond_to do |format|
      format.turbo_stream {  }
    end
  end
  
  def create
    @package = @happening.packages.new(safe_params)
    respond_to do |format|
      if @package.save
        @animate = true
        logger.debug "\n\n saved\n\n"
        format.turbo_stream { }
      else
       format.turbo_stream { render action: "new" }
      end
    end
  end
  
  

  
  def destroy
    
    respond_to do |format|
      if @package.destroy
       
          format.html {  }
           format.turbo_stream { }
       
      else
        logger.debug "\n\n@package errors #{@package.errors.full_messages}\n\n"
        flash.now.alert = error_message_on_delete_to_list(@package)
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  
  


  private
  
  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
   # @recording_admin = true
    @package = @happening.packages.find( params[:id] ) if params[:id]
    @recording_admin =true
  end

  
#  def load_bundleable_items
#    @bundled_packages = BundleItem.bundle_packages_hashed_and_plucked_by_bundle_ids([@happening.id])
#    @bundled_resources = BundleItem.bundle_resources_hashed_and_plucked_by_bundle_ids([@happening.id])
#  end
#  
#  def load_collections_for_recordings
#    @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happening.id])
#    @speakers = Speaker.speakers_for_sound_admin_grouped_by_happening_id([@happening.id]).to_h
#    logger.debug "\n\n.@grouped_recordings #{@grouped_recordings.inspect} \n\n"
#  end
  
  def safe_params
    safe_attributes =  [:format_id]
    params.require(:package).permit(*safe_attributes)
  end
end
