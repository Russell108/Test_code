class Allocate::Courses::MembershipsController < ApplicationController
  include CustomerRender
  
  before_action :authenticate_user!
  before_action :load_and_authorize_course
  
  
  
  def index
    @memberships = @course.memberships.includes([:user])
    .order('users.surname').references(:users)
    @memberships =  @memberships.user_search_limit_search_to_2_strings(params[:course_memberships_search])
    .page(params[:page])   
    @course_meets = @course.meets.includes(:registrations).order("start_date")
    @active_tab = 'Register'
    unless( params.has_key? :full_page)
     respond_to do |format|
        format.turbo_stream{render  "_index" }
        format.html{ }
     end
    end
  end
  
  def show
    @animate_course_member =true
     @membership = @course.memberships.includes([:user]).find(params[:id])
     @course_meets = @course.meets.includes(:registrations).order("start_date")
  end
  
  

  def create
    @animate_course_member =true
    @membership = @course.memberships.find_or_initialize_by(user_id: params[:membership][:user_id]) do|membership|
      membership.mbr_type_id = params[:membership][:mbr_type_id]
    end
    if@membership.persisted?
      flash.now[:alert] ="#{@membership.user.fullname} is already a member.<BR> Their membership has not been changed".html_safe
    elsif @membership.save
    else
      flash.now[:alert] ="This membership cannot be created for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
    end 
    @close_modal =true
     @course_meets = @course.meets.includes(:memberships).order("start_date")
     @user = @membership.user
    respond_to do |format|
       format.turbo_stream {}
     end
  end
  
  def edit
    @membership = @course.memberships.includes([:user]).find(params[:id])
    @happening  = Meet.find(params[:happening_id]) if (params.has_key? :happening_id) 
  
  end
  
  
  def update
    @membership = @course.memberships.includes([:user]).find(params[:id])
    @course_meets = @course.meets.order("start_date")
   # @happening  = Meet.find(params[:happening_id]) if (params.has_key? :happening_id) 
    if @membership.update(safe_params)
      redirect_to allocate_course_membership_path(@course,@membership  ), status: 303
    else
      respond_to do |format|
        flash.now[:alert] = (@membership.errors.full_messages.join("<BR>")).html_safe
        format.html {  }
      end
    end
  end
  
  def destroy
    @happening  = Meet.find(params[:happening_id]) if (params.has_key? :happening_id) 
    @membership = @course.memberships.includes([:user]).find(params[:id])
     @animate_course_member =true
    if @membership.destroy
      @user = @membership.user
       @course_meets = @course.meets.includes(:registrations).order("start_date")
     # load_collections_for_customer_allocation_render(@happening, [@user]) if @happening
      respond_to do |format|
        format.html {  }
        format.turbo_stream { render turbo_stream: turbo_stream.remove("register_#{@membership.id}" ) }
      end
    else
      respond_to do |format|
         format.turbo_stream {
          flash.now[:alert] ="This membership cannot be destroyed for the following reasons:<BR><BR>" + (@membership.errors.full_messages.join("<BR>")).html_safe
          render :template => '/shared/flash'
        }
      end
    end
  end 
  
  

  private
  
  def load_and_authorize_course
    @course = Course.find(params[:course_id])
    authorize [:admin, @course], :update?
  
  end
    
	def safe_params
   		safe_attributes =
     		[ :user_id,
     		 :mbr_type_id,
          registrations_attributes: [:happening_id]
    		 ]
  		params.require(:membership).permit(*safe_attributes)
 	end
end
