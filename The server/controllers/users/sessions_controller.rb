# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController

   layout 'navbar_free'
  respond_to :html, :turbo_stream
  # GET /resource/sign_in
 
  def new
   # logger.debug "\n\nUsers::SessionsController def new\ line 10n\n"
    if (frame_id  =  request.headers["Turbo-Frame"])
      render template: "users/sessions/request_login", locals:{frame_id: frame_id,redirect_href: request.referer}
    else
      render template: "users/sessions/new", locals:{resource: User.new}
    end
  end
  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
  
  private

end
