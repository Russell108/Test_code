class Allocate::Courses::RegistrationsController < ApplicationController
  include CustomerRender
  

  before_action :authenticate_user!
  before_action :load_and_authorize_happening
 
 
  def create
    @registration= @happening.registrations.new(create_params)
    if @registration.save
      logger.debug "\n\n@registration inspect #{@registration.inspect}\n\n"
     redirect_to allocate_course_membership_path(course_id: @happening.happenable_id , id: @registration.membership_id , )
    else
      respond_to do |format|
        flash.now.alert = ("Cannot be registered for the following reasons " + 
        @registration.errors.full_messages.join("<BR>")).html_safe
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  
  def destroy
    @registration = Registration.where(happening_id:@happening.id ).find params[:id]
     if @registration.destroy
       redirect_to allocate_course_membership_path(course_id: @happening.happenable_id ,id: @registration.membership_id),
       status: 303
     else
       respond_to do |format|
         flash.now.alert = error_message_on_delete_to_list(@registration)
         format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
       end
     end
  end
  
  private
  def load_and_authorize_happening
    @happening= Meet.find(params[:meet_id])
    authorize [:admin, @happening], :update?
  end
  
 	def create_params
    safe_attributes =[  :membership_id]
    params.require(:registration).permit(*safe_attributes)
  end
  

  

end
