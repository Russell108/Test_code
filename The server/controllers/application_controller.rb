class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  protect_from_forgery prepend: true
  allow_browser versions: :modern

  before_action :store_user_location!, if: :storable_location?
   before_action :check_mission_control_access,  if: :mission_control_controller?
  
  include Pundit::Authorization
   
  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || events_path
  end
  rescue_from ActionController::InvalidAuthenticityToken, :with => :invalid_authenticity_token
  
  after_action :reset_flash 
 
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized 


  
  
  rescue_from ActiveRecord::RecordNotFound do |exception|
      message = ("<p>Sorry we could not find the #{controller_name.singularize  },<BR> if you think this is an error please email us at: support at drusound.com.").html_safe
      respond_to do |format|
        format.html { flash[:alert]= message
             redirect_to root_path}
        format.turbo_stream {flash.now[:alert]= message
            render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals:{delay: 5000})}
        format.pdf {flash[:alert]= message
              redirect_to(action: :index)}
      end 
  end
  
  
  private
  def invalid_authenticity_token
     Rails.logger.info "\n\n\n invalid_authenticity_token #{request.inspect}\n\n\n"
     message ="Your session has expired please refresh the page and log back in."
     flash.now[:alert]= message
     if (frame_id  =  request.headers["Turbo-Frame"])
       render template: "users/sessions/request_login", locals:{frame_id: frame_id,redirect_href: request.referer}
     else
       render template: "shared/flash", locals:{frame_id: frame_id}
    end
  end
   
  def error_message_on_delete_to_list(object)
    message= "The #{object.class.name.humanize} cannot be deleted,<BR> for the following #{'reason'.pluralize(object.errors.size)}:<BR>"
    message << "<ul class='list-unstyled'>"
    object.errors.full_messages.each do |m| 
      message << "<li>#{m}</li>"
    end
    message << "</ul>"
    return message.html_safe
  end
  
  def error_message_on_purge_transcription(object)
    message= "The Transcription cannot be deleted,<BR> for the following #{'reason'.pluralize(object.errors.size)}:<BR>"
    message << "<ul class='list-unstyled'>"
    object.errors.full_messages.each do |m| 
      message << "<li>#{m}</li>"
    end
    message << "</ul>"
    return message.html_safe
  end
  
  def error_message_to_list(object)
    message= "This #{object.class.name} cannot be deleted, for the following reasons:<BR>"
    message << "<ul class='list-unstyled'>"
    object.errors.full_messages.each do |m| 
      message << "<li>#{m}</li>"
    end
    message << "</ul>"
    return message.html_safe
  end
  
 
  # Its important that the location is NOT stored if:
  # - The request method is not GET (non idempotent)
  # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an 
  #    infinite redirect loop.
  # - The request is an Ajax request as this can lead to very unexpected behaviour.
  def storable_location?
    
     !devise_controller? && request.get? && is_navigational_format? && !devise_controller? && !request.xhr? 
  end
       
  def store_user_location!
   # logger.debug "\n\nstore_user_location!\n\n"
    # :user is the scope we are authenticating
    store_location_for(:user, request.fullpath)
  end
  

  
  
  def reset_flash
   #logger.debug "\n\n reset_flash #{turbo_frame_request?}\n\n"
  #  flash.discard if turbo_frame_request?
  end
  


   
   def user_not_authorized
    @message ||= "You don't have access to this resource.".html_safe 
     logger.debug "\n\n  user_not_authorized #{current_user.email}\n\n"
     respond_to do |format|
       format.html {  
         if (frame_id  =  request.headers["Turbo-Frame"])
           request.variant = :turbo
            logger.debug "\n\nnot authorised variant\n\n"
           render template: "shared/flash", locals:{frame_id: frame_id,message: "Currently are not authorised to access this resource. Please contact support"}
         else
            logger.debug "\n\nnot authorised html\n\n"
          flash[:alert] = @message
         redirect_to "/" 
       end
       }
        flash.now[:alert]= @message
       format.turbo_stream{
         logger.debug "\n\nnot authorised turbo\n\n"
           render turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash", locals:{delay: 4000})}
           format.pdf { flash[:alert]= @message
          redirect_to root_path }
     end
   end  
   
   # for authorisation of mission control controllers
   def mission_control_controller?
      is_a?(::MissionControl::Jobs::ApplicationController)
    end
    
    def check_mission_control_access
      logger.debug("\n\n we sould authorize the user\n\n")
      authorize :application, :site_admin?
    end
   

end
