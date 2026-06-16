class Admin::BundleItemsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_and_authorize

  def index
    load_assets
   logger.debug "\n\n flash  #{flash.inspect}\n\n"
    respond_to do |format|
      format.turbo_stream {  }
      format.html
    end
  end
  

  def create
    
      @bundle_item = @bundle.bundle_items.new(safe_params)
      if @bundle_item.save
         redirect_to action: :index
      else
        logger.debug "\n\n not saved in create action\n\n"
        flash.now[:alert] = (@bundle_item.errors.full_messages.join("<BR>")).html_safe
        render :template => '/shared/flash'
      end
   
  end
  
 def destroy
     
    @bundle_item = @bundle.bundle_items.find params[:id]
    
    if @bundle_item.destroy
     
       redirect_to action: :index
   
    else
      flash[:alert] =  ("This bundle cannot be deleted, for the following reasons:<BR><BR>" + @bundle.errors.full_messages.join("<BR>")).html_safe
       render :template => '/shared/flash'
    end
  end

    private
    
    def load_and_authorize
      
      @bundle = Bundle.find params[:bundle_id]
      @happening = @bundle.happening
      authorize [:admin, @happening], :update?
    end
    
  def safe_params
    safe_attributes =  [:bundleable_type, :bundleable_id]
    params.require(:bundle_item).permit(*safe_attributes)
  end
  
 
  
  def load_assets
  #  @bundled_packages = @bundle.bundle_items.plucked_and_hashed_by_bundleable_type('Package')
  #  @bundled_resources = @bundle.bundle_items.plucked_and_hashed_by_bundleable_type('Resource')
#   @speakers = Speaker.speakers_for_sound_admin_grouped_by_happening_id([@happening.id]).to_h
    @grouped_recordings = Recording.for_sound_admin_grouped_by_happening_id([@happening.id])
  end
end


