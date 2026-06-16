class Admin::ProtectedAdminsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_administerable
   
  
  def index
     logger.debug "\n\n@ protected admin controller index \n\n"
      @active_tab = 'protected_admins'
     @protected_admins  = @happening.protected_admins
     @protected_admins  =  @protected_admins.page(params[:page])
     unless( params.has_key? :full_page)
      respond_to do |format|
         format.turbo_stream{render  "_index" }
         format.html{ }
      end
     end
  end
  
  def show
    @animate = (params.has_key? :animate) ?  true : false
 #   @acquired_package=  @happening.acquired_packages.find params[:id]
     @protected_admin  = @happening.protected_admins.find(params[:id])
    
  end
  
 
  def create
     @animate = (params.has_key? :animate) ?  true : false
    @protected_admin= @happening.protected_admins.new(safe_params)
    if @protected_admin.save
       @animate =true
      respond_to do |format|
        format.turbo_stream {}
      end
    else
      respond_to do |format|
         format.turbo_stream {
          flash.now[:alert] = ("#{(@protected_admin.user.fullname )if 
          @protected_admin.user} cannot be added, for the following reasons:<BR><BR>" +
                       @protected_admin.errors.full_messages.join("<BR>")).html_safe
          render :template => '/shared/flash'
        }
      end
    end
   end
   
   def destroy
       @protected_admin = @happening.protected_admins.includes(:user).find params[:id]
       @animate_protected_admin =true
       @remove_after_animate =true
       if @protected_admin.destroy
        respond_to do |format|
            format.turbo_stream {}
        end
      else
        respond_to do |format|
          flash.now.alert = error_message_on_delete_to_list(@protected_admin)
          format.turbo_stream{   render :template => '/shared/flash' }
        end
      end
   end  
  
  private
  
  def load_administerable
    @happening = Happening.find(params[:happening_id])
    authorize [:protectedadmin, @happening], :update?
  end
 
 	def safe_params
    safe_attributes =[  :user_id]
    params.require(:protected_admin).permit(*safe_attributes)
  end
  
  
 
  
end
