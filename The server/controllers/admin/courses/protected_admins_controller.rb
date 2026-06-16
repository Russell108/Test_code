class Admin::Courses::ProtectedAdminsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_administerable
  
  
  def index
     logger.debug "\n\n@ protected admin controller index \n\n"
     @active_tab = 'protected_admins'
     @protected_admins  = @course.protected_admins.includes(:user).order("users.surname")
     @protected_admins  =  @protected_admins.page(params[:page])
     logger.debug "\n\n @active_tab protected admin controller index #{@active_tab.inspect}\n\n"
     unless( params.has_key? :full_page)
      respond_to do |format|
         format.turbo_stream{render  "_index" }
         format.html{ }
      end
     end
  end
  
  def show
    @animate_admin = true
    @protected_admin  = @course.protected_admins.find(params[:id])
  end
  
  def create
       @protected_admin= @course.protected_admins.new(safe_params)
            
           if @protected_admin.save
             @animate =true
             respond_to do |format|
              
              format.turbo_stream {}
             end
           else
             logger.debug "\n\n this is happeniomng\n\n"
             flash.now[:alert] = (@protected_admin.errors.full_messages.join("<BR>")).html_safe
             render :template => '/shared/flash'
           end
      
   end
   
   def destroy
       @protected_admin = @course.protected_admins.includes(:user).find( params[:id])
       #@animate_protected_admin-true
       if @protected_admin.destroy
         respond_to do |format|
           logger.debug"\n\ndestroy in Admin::Courses::ProtectedAdminsController #{@protected_admin.inspect}\n\n"
             format.turbo_stream {render turbo_stream.remove("protected_admin_#{@protected_admin.id}" )  }
             
         end
       else
         flash.now[:alert] =  ("This role cannot be deleted, for the following reasons:<BR><BR>" + @protected_admin.errors.full_messages.join("<BR>")).html_safe
        
            render :template => '/shared/flash'
       end
   end  
  
  private
  
  def load_administerable
    @course = Course.find(params[:course_id])
    authorize [:admin, @course], :update?
  end
 
 	def safe_params
    safe_attributes =[  :user_id]
    params.require(:protected_admin).permit(*safe_attributes)
  end
  
  
 
  
end

