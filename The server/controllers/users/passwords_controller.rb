# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  layout 'navbar_free'
  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
   def create
     if(user=User.find_by_email(params[:user][:email]) rescue nil)
       if user.archived
         flash[:alert] = "The user's acount has been archived. If this is unexpected please contact support at drusound.com"
          redirect_to root_path and return
       end
       if !user.confirmed?
         # logger.debug "\n\nUser's account needs  setup send email\n\n"
          flash[:alert] = "Please check your emails for the email titled<BR> 'Drusound account setup'.<BR>
                           If you cannot see it please check your spam folder.".html_safe
          AdminSalesMailer.with(user_id: user.id).resend_account_activation_email.deliver_later 
          redirect_to root_path and return
        end
     end
   super 

  end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  # def update
  #   super
  # end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end
  
  def render(*args)
  # add_devise_errors_to_flash if devise_controller?
   if(action_name == 'create') 
     if resource.errors.empty?
       redirect_to root_path and  return
     end
   end
   if(action_name == 'update') 
     if resource.errors.empty?
       logger.debug "\n\n def render(*args) for update no errors\n\n"
       flash[:notice]= "Great You are now signed in as #{resource.email}.<BR>
         If you wish to change your login email you can do so from your account dropdown or from this link
           <a href='#{edit_user_registration_url}'data-turbo='false'>update email in account profile</a>".html_safe
       redirect_to root_path and  return
     end
   end
   super # <- view render happens here
  end
  
end
