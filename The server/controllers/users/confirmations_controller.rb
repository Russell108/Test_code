# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation/new
  # def new
  #   super
  # end

  # POST /resource/confirmation
   def create
       logger.debug "\n\nUsers::ConfirmationsController < Devise::ConfirmationsController\n\n"
     if(user=User.find_by_email(params[:user][:email]) rescue nil)
       if !user.confirmed?
          logger.debug "\n\nUser needs account set up email\n\n"
          user.send_confirmation_instructions
          if current_user
            flash[:notice]= "#{user.fullname} has been sent a new account setup email"
            redirect_to users_path
          else
            flash[:notice]= "We have sent you a new account setup email"
            redirect_to root_path
          end
        return 
       end
     end
    
     super
     logger.debug "\n\nresource.errors.full_messages #{}\n\n"
   end

  # GET /resource/confirmation?confirmation_token=abcdef
   def show
     user = User.find_by_confirmation_token(params[:confirmation_token])
     if user
      logger.debug"\n\n user.confirmed? #{user.confirmed?}\n\n"
      logger.debug"\n\nuser.pending_reconfirmation? #{user.pending_reconfirmation?}\n\n"
      return unless (!user.confirmed? or user.pending_reconfirmation?)
     end
     super
   end
   
   
   def render(*args)
   # add_devise_errors_to_flash if devise_controller?
    if((action_name == 'create') and current_user and !params[:user][:email].blank? )
      flash[:notice]= "#{resource.fullname} has been sent a new confirmation email"
      
      redirect_to users_path
      return
    end
    super # <- view render happens here
   end

  # protected

  # The path used after resending confirmation instructions.
  # def after_resending_confirmation_instructions_path_for(resource_name)
  #   super(resource_name)
  # end

  # The path used after confirmation.
  # def after_confirmation_path_for(resource_name, resource)
  #   super(resource_name, resource)
  # end
end

#.  _support@drusound.com