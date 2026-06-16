class Allocate::MembershipsController < ApplicationController#Allocate::OrdersController
  include CustomerRender
  before_action :authenticate_user!
  before_action :load_and_authorize_happening
  

  
  def new
    
    @membership = @happening.memberships.new(user_id:params[:user_id])

  end
  
  
  def create
    logger.debug "\n\n create_params #{create_params}\n\n"
    @membership= @happening.memberships.find_or_initialize_by(user_id: create_params[:user_id]) do |membership|
      membership.mbr_type_id = create_params[:mbr_type_id]
    end
    logger.debug "\n\n create_params[:mbr_type_id] #{create_params[:mbr_type_id]}\n\n"
    logger.debug "\n\n @membership.mbr_type_id #{@membership.mbr_type_id}\n\n"
    logger.debug "\n\n @membership.mbr_type_id  = create_params[:mbr_type_id]  #{@membership.mbr_type_id == create_params[:mbr_type_id].to_i }\n\n"
    if (@membership.persisted? )
      message= "#{@membership.user.fullname} is already a #{ @membership.mbr_type.name} member"
      if ( @membership.mbr_type_id != create_params[:mbr_type_id].to_i)
        message<< " #{@membership.user.fullname} is already a #{ @membership.mbr_type.name} member. Please edit if membership type needs changing"  .html_safe
      end
    end
    if @membership.save
      load_collections_for_customer_allocation_render(@happening, [@membership.user], params[:team2import])
     
       flash.now[:error] = message unless message.blank?
      logger.debug "\n\n saved\n\n"
      respond_to do |format|
         format.turbo_stream {}
       end
    else
      respond_to do |format|
        logger.debug "\n\n not saved\n\n"
         format.turbo_stream {
          flash.now[:error] ="This membership cannot be created for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
          render :template => '/shared/flash'
        }
      end
    end
  end
  
  def edit
      @membership = @happening.memberships.includes(:user).find(params[:id])
     
  end
    
  def update
      @membership = @happening.memberships.includes(:user).find(params[:id])
      @user=@membership.user
      if @membership.update(update_params)
        redirect_to allocate_happening_customer_path( id: @membership.user_id,happening_id: @happening.id, team2import: params[:team2import], animate: true  )
      else
        respond_to do |format|
           format.turbo_stream {
            flash.now[:alert] ="This membership cannot be edited for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
            render :template => '/shared/flash'
          }
        end
      end
  end
  
  def destroy
      @membership = @happening.memberships.find( params[:id])
      if @membership.destroy
        respond_to do |format|
          format.turbo_stream {render turbo_stream: turbo_stream.remove("customer_#{@membership.user_id}" )}
      end
      else
       
        flash.now[:alert] =  ("This membership cannot be deleted, for the following reasons:<BR><BR>" + @membership.errors.full_messages.join("<BR>")).html_safe
       
            render :template => '/shared/flash'
      end
  end  
  
      private
    
    def load_and_authorize_happening
      @happening= Happening.find(params[:happening_id])
      authorize [:admin, @happening], :update?
    end
    
   	def create_params
      safe_attributes =[  :user_id,
                           :mbr_type_id]
      params.require(:membership).permit(*safe_attributes)
    end


    def update_params
      return {} unless params[:membership]
      safe_attributes =[
             :mbr_type_id
         ]
      params.require(:membership).permit(*safe_attributes)
    end
  
   
  
  end

