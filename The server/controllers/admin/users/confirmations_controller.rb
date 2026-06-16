class Admin::Users::ConfirmationsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_authorization
  
  def create
    @user= User.find params[:password][:user_id]
    if ( !@user.confirmed? || @user.pending_reconfirmation?)
         @user.update_attribute('confirmation_sent_at', Time.now)
        @user.send_reconfirmation_instructions
        flash.now[:notice] = "Confirmation instructions have been sent to #{@user.forename}, #{@user.unconfirmed_email || @user.email}."
    else
      flash.now[:alert] = "user with email: #{@user.email} is fully confirmed."
    end
  end
  
  def check_authorization
    authorize User
    
  end
  
end
