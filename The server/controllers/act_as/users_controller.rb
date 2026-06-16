class ActAs::UsersController < ApplicationController
  before_action :authenticate_user!
  
  def show
    logger.debug "\n\ncurrent_user #{current_user}\n\n"
    return unless current_user.is_active_site_admin?
    bypass_sign_in(User.find(params[:id]))
    #sign_in(:user, User.find(params[:id]))
   redirect_to root_url( ) # or user_root_url
  end
end



