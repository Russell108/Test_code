class Allocate::Meets::RegistrationsController < ApplicationController
 # include CustomerRender
  

  before_action :authenticate_user!
  before_action :load_and_authorize_happening
  

  def new
    @registration = @happening.registrations.new(user_id:params[:user_id])
    
  end
 
  def create
    if (create_params.has_key? :user_id)
      logger.debug "\n\ncreate_params.has_key? :user_id\n\n"
      @membership =  @happening.course.memberships.find_or_create_by(user_id: create_params[:user_id]) do|membership|
        membership.mbr_type_id =create_params[:mbr_type_id] 
        logger.debug "\n\n membership #{membership.inspect}\n\n"
      end
       logger.debug "\n\n @membership #{@membership.inspect}\n\n"
      unless @membership.valid?
        flash.now.alert = "Membership could not be found or created " 
        respond_to do |format| 
          format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
        end
        return
      end
      logger.debug "\n\nmembership is valid\n\n"
      unless(@membership.mbr_type_id == create_params[:mbr_type_id].to_i)
        logger.debug "\n\n we shall redirect\n\n"
        flash[:alert] = "Already has #{@membership.mbr_type.name} membership" 
        redirect_to allocate_happening_customer_path( id: @membership.user_id, happening_id:	 @happening.id, team2import: params[:team2import] ),
        status: 303
        return
      end
      logger.debug "\n\n existing membership if any not conflicted\n\n"
      
      @registration= @happening.registrations.find_or_initialize_by(membership_id: @membership.id)
      logger.debug "\n\n@registration #{@registration.inspect}\n\n"
      flash[:alert] = "Already registeresd"  if @registration.persisted?
    else
      @registration= @happening.registrations.new(create_params)
    end
   
   
    if @registration.save
      logger.debug "\n\n@registration inspect #{@registration.inspect}\n\n"
      redirect_to allocate_happening_customer_path( id: @registration.membership.user_id, happening_id:	 @happening.id,
       team2import: params[:team2import] , animate: true ),
      status: 303
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
     #  redirect_to allocate_course_membership_path(course_id: @happening.happenable_id ,id: @registration.membership_id  )
        redirect_to allocate_happening_customer_path( id: @registration.membership.user_id, happening_id:	 @happening.id, team2import: params[:team2import], animate: true  ),
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
    safe_attributes =[  :membership_id,:user_id, :mbr_type_id]
    params.require(:registration).permit(*safe_attributes)
  end
  

end
