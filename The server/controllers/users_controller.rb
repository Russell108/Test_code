class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :check_authorization
  before_action :set_purpose
  before_action :set_index_params, only: :index


  
 
  
  def index
    @animate =false
    logger.debug "\n\n safe_search_params line 13 #{safe_search_params}\n\n"
    @safe_search_params = {user_search: safe_search_params}
    @parent_id =params[:parent_id]
   @current_user_active_site_admin = current_user.is_active_site_admin?
    @user_search =UserSearch.new(safe_search_params)
    @users = User.user_search_limit_search_to_2_strings(@user_search.search)
                .order(:surname)
                .page(params[:page])
   
    if(["happening_sales", "protected_admin" ].include? params[:purpose])
      ( @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
    end
    if(["course_membership","course_protected_admin"].include? params[:purpose])
      @parent = Course.find params[:parent_id]
    elsif(params[:purpose]=="meet_sales")
      (  @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
      @course = @parent.course
    end
    @flash_delay = 4000
  end
  
  def show
    @flash_delay =8000
    @current_user_active_site_admin = current_user.is_active_site_admin?
    if(["happening_sales", "protected_admin" ].include? params[:purpose])
      ( @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
      logger.debug "\n\n@parent.inspect #{@parent.inspect}\n\n"
    end
    if(["course_membership","course_protected_admin"].include? params[:purpose])
      @parent = Course.find params[:parent_id]
    elsif(params[:purpose]=="meet_sales")
      (  @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
      @course = @parent.course
    end
    unless @user= User.find(params[:id]) 
      redirect_to users_path
    end
    @active_tab = 'Details'
    logger.debug "\n\n\n\n"
   @animate = true #(params[:animate]  == 'true' ) ? true : false

   @scrollTo=true 
  end
  
  def new
    @user= User.new()
   # respond_to do |format|
   #   format.turbo_stream { render turbo_stream: turbo_stream.replace("new_user", template: "/users/new") }
   #   format.html         { }
   # end
  end
  
  def create
    
    @user= User.new()
    @user.assign_attributes(safe_params)
    # unless(params[:user][:send_email] =="1") # send reconfirmation
    @user.skip_confirmation_notification!
    @skip = true
    @current_user_active_site_admin = current_user.is_active_site_admin?
    respond_to do |format|
      if @user.save
        @animate= true
        if(["happening_sales", "protected_admin" ].include? params[:purpose])
     
          ( @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
          logger.debug "\n\n@parent.inspect #{@parent.inspect}\n\n"
        end
        if(["course_membership","course_protected_admin"].include? params[:purpose])
          @parent = Course.find params[:parent_id]
      
        elsif(params[:purpose]=="meet_sales")
          (  @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
          @course = @parent.course
        end
        format.turbo_stream {}
       
      else
        logger.debug "\n\n@user.errors #{@user.errors.full_messages}\n\n"
        format.html { render action: "new" }
      
      end
    end
  end

  def edit
    @user= User.find( params[:id])
  end
  
  def update
     @user= User.find(params[:id])
     @user.assign_attributes(safe_params)
     # unless(params[:user][:send_email] =="1") # send reconfirmation
     @user.skip_reconfirmation! 
  #   authorize @user
     #  end
     if(["happening_sales", "protected_admin" ].include? params[:purpose])
     
       ( @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
     end
     if(params[:purpose]=="course_membership")
       @course = Course.find params[:parent_id]
      
     elsif(params[:purpose]=="meet_sales")
       (  @parent = Happening.find params[:parent_id])unless params[:parent_id].blank?
       @course = @parent.course
     end
   (@user.current_admin_centre = current_user.centre) if params[:user][:sponsor_id]  
    if @user.save
      
   
     
         redirect_to user_url(@user, purpose: params[:purpose], parent_id: params[:parent_id], scrollTo: true, animate:true)
    else
      respond_to do |format|
        format.html { render  "edit" }
      end
    end
    
  end
   
  def destroy
    @user= User.find(params[:id])
    if @user.destroy
     
      respond_to do |format|
         format.html{flash[:notice]="user #{@user.email} succssfully deleted"
          redirect_to users_path }
        format.turbo_stream { render turbo_stream: turbo_stream.remove("user_#{@user.id}") }
      end
    else
      respond_to do |format|
        logger.debug "\n\n@user errors #{@user.errors.full_messages}\n\n"
        flash.now.alert = error_message_on_delete_to_list(@user)
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end 
  end
  
  rescue_from ActionController::InvalidAuthenticityToken, with: :alert_csrf
  
  private
  
  def error_csrf
   #  logger.debug "\n\n what to do\n\n "
   #   logger.debug "\n\n what to do for \n\n #{action_name}"
      if (action_name == "update")
        redirect_to action: "edit"
      elsif (action_name == "create")
        redirect_to action: "new"
      end
      
  end
  
  def check_authorization
    authorize User
   #logger.debug "\n\n UsersController user_signed_in? #{user_signed_in?}"
   #logger.debug " UsersController log_request #{request.format}\n\n"
    
  end
  
  def safe_attributes
    safe_attributes =
      [:email,
       :forename,
       :surname,
       :send_email,
       :family_mailings
      ]
   safe_attributes.push([ :talk_type_id, :sponsor_id, :sponsor_notes, :archived]) if(current_user.has_current_centre_assignment?(["Family"]) 
    )
  end

  
  def safe_params
   
      
     params.require(:user).permit(*safe_attributes)
  end
  
  def safe_search_params
    if( params.has_key?( :user_search) and !params[:user_search].empty?)
      
    safe_attributes =
      [  :search
      ]
      params.require(:user_search).permit(*safe_attributes)
      
    end
  end
  
  def set_index_params
    @safe_search_params = {parent_id: params[:parent_id], purpose: params[:purpose], user_search: params[:user_search] } rescue {}
    
    logger.debug "\n\n@safe_search_params #{@safe_search_params}\n\n"
  end
  
 

  def set_purpose
    @purpose = params[:purpose] || 'admin'
    @parent_id = params[:parent_id] 
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
      flash[:alert] = ("<p>Sorrry we could not find the user,<BR> from the id provided.").html_safe
      redirect_to users_path
  end
  
  
end
