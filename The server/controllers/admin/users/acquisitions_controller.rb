class Admin::Users::AcquisitionsController < ApplicationController
  include  AdminAcquisitionRender
  before_action :authenticate_user! 
  before_action :load_and_authorize
  
  
  def index
    @active_tab = 'Acquisitions'
   
    @happenings = @resource_search.happenings.includes(:venue)
   
    @happenings= @happenings.page(params[:page])#.per_page(10)
    
   load_collections_for_user_acquisitions_render(@user.id, @happenings.collect(&:id))
   logger.debug "\n\n@@acquired_resources #{@acquired_resources}\n\n"
   respond_to do |format|
      format.turbo_stream{ }
      format.html{render template: "acquire/users/show" }
   end
  end
  
  
   
  private
  
  def load_and_authorize
    authorize User
    @user =User.find params[:user_id]
    @resource_search=ResourceSearch.new(params[:resource_search]) 
     @resource_search.happening_policy_scope = Happening.with_acquisitions_for_user(@user.id)
  end
  
 
  
end
