class Groups::GroupMembershipsController < ApplicationController
      before_action :authenticate_user! 
      before_action :load_and_authorize
      before_action :set_purpose, except: [:destroy]
      
   
  
  
  def index
     @group_memberships = @group.group_memberships.includes(:user).order("users.surname").page(params[:page])
     #if params.has_key?(:page)
     #  respond_to do |format|
     #    format.turbo_stream { render  "groups_index"}
     #    format.html
     #  end
     #end
  end
  
  def show
    @group_membership = @group.group_memberships.includes(:user).find( params[:id])
    @animate =true
  end
  
	def create
      @group_membership= @group.group_memberships.new(create_params)
     # @membership.user_id = params[:user_id]
      respond_to do |format|
          if @group_membership.save
            @animate =true
            @scrollTo= true
              format.html { }
             format.turbo_stream {}
          else
             flash[:alert] =  @group_membership.errors.full_messages.join("<BR>").html_safe
            format.turbo_stream { render :template => '/groups/group_memberships/flash'}
            
          end
      end
  end
  
  
 
  
  def destroy
      @group_membership = @group.group_memberships.includes(:user).find( params[:id])
      if @group_membership.destroy
        
        respond_to do |format|
           format.turbo_stream { render turbo_stream:   turbo_stream.remove( "group_membership_#{@group_membership.id}")}
        end
      else
        flash[:alert] =  ("This membership cannot be removed, for the following reasons:<BR><BR>" + @group_membership.errors.full_messages.join("<BR>")).html_safe
         
            render :template => '/shared/flash'
      end
  end  
  
  private
  
  def load_and_authorize
    authorize User, :index?
    @group = Group.find(params[:group_id])
  end
  
  def create_params
    safe_attributes =[
           :user_id
       ]
    params.require(:group_membership).permit(*safe_attributes)
  end
  
  def set_purpose
    @purpose = params[:user_purpose] || 'admin'
  end
  
end

