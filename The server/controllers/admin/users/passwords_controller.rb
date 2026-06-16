class Admin::Users::PasswordsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_authorization
  
  def create
    @user =User.find params[:password][:user_id]
    if @user.confirmed?
      @user.send_reset_password_instructions
    else
     @user.update_attribute('confirmation_sent_at', Time.now)
      @user.send_confirmation_instructions
    end
    flash.now[:notice] ="Password reset instructions have been sent to #{@user.email}."
  end
  
  def check_authorization
    authorize User
    
  end
  
end
