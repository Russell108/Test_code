class Admin::HappeningsController < Admin::SuperHappeningsController
  before_action :authenticate_user! 
  before_action :set_admin_variables

  
	def index
   
    
    authorize [:admin, Happening]
    @search_title= 'Happening Search'
    @resource_search_url= admin_happenings_url()
    @resource_search.happening_policy_scope = policy_scope([:admin, Happening])
    super
	end
  
#  def update
#    @happening=Happening.find(params[:id])
#    authorize [:admin, @happening], policy_class: Admin::HappeningPolicy
#     @happening.attributes = update_params
#     @happening.editable_when_locked= ["end_date", "type","happenable_id", "happenable_type","editable_when_locked"]
#	  respond_to do |format|
#      logger.debug "\n\n@happening.inspect pre #{@happening.inspect}\n\n"
#	    if @happening.save
#         logger.debug "\n\n@happening.inspect post save #{@happening.inspect}\n\n"
#        format.html { }
#	    else
#         logger.debug "\n\n@happening.inspect save failed #{@happening.inspect}\n\n"
#        flash.now[:alert] =  (@happening.errors.full_messages.join("<BR>")).html_safe
#        @happening.reload
#        format.html {}
#	    end
#	  end
#  end
  
  private
  def set_admin_variables
    @site_admin = current_user.is_active_site_admin?
  end
#  
#  def update_params
#    safe_attributes =[
#           :protected
#       ]
#    safe_attributes.push([ :type,:happenable_id]) unless(@happening.type=="Meet")
#    params.require(:happening).permit(*safe_attributes)
#  end
 
  
  
end
