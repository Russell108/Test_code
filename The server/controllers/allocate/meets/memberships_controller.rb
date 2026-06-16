class Allocate::Meets::MembershipsController < ApplicationController#Allocate::OrdersController
 
  before_action :authenticate_user!
  before_action :load_and_authorize_happening
  
 
  
  def new
    
    @membership = @course.memberships.new(user_id:params[:user_id])
    respond_to do |format|
       format.turbo_stream { render turbo_stream: turbo_stream.replace("membership_for_user_#{@membership.user_id}", partial: "new") }
    end
  end
  
 
  
  def create
    @membership= @course.memberships.new(create_params)
    if @membership.save
      respond_to do |format|
         format.turbo_stream {}
       end
    else
      respond_to do |format|
         format.turbo_stream {
          flash[:notice] ="This membership cannot be created for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
        
        }
      end
    end
  end
  
  def edit
      @membership = @course.memberships.includes(:user).find(params[:id])
    
  end
    
  def update
      @membership = @course.memberships.includes(:user).find(params[:id])
      @user=@membership.user
      logger.debug "\n\n@membership update_params #{update_params}\n\n"
      if @membership.update(update_params)
        logger.debug "\n\n@membership #{@membership.inspect}\n\n"
        redirect_to allocate_happening_customer_path( id: @membership.user_id,happening_id: @happening.id, team2import: params[:team2import], animate: true ),
        status: 303
      else
        respond_to do |format|
           format.turbo_stream {
            flash.now[:alert] ="This membership cannot be edited for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
            render :template => '/shared/flash.turbo_stream.erb'
          }
        end
      end
  end
  
  def destroy
      @membership = @course.memberships.find( params[:id])
      if @membership.destroy
        logger.debug "\n\n we are hjere\n\n"
        redirect_to allocate_happening_customer_path( id: @membership.user_id, happening_id: @happening.id, team2import: params[:team2import], animate: true  ),
        status: 303
      else
        flash.now[:alert] =  ("This membership cannot be deleted, for the following reasons:<BR><BR>" + @membership.errors.full_messages.join("<BR>")).html_safe
        render :template => '/shared/flash'
      end
  end  
  
  
  
      private
    
    def load_and_authorize_happening
      @happening= Meet.find(params[:meet_id])
      authorize [:admin, @happening], :update?
       @course = @happening.course
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

