class GroupsController < ApplicationController
    before_action :authenticate_user! 
  before_action :set_purpose, except: [:destroy]
   

  
  def index
   
     authorize Group
     @groups = Group.all.order("title")
     @groups = @groups.where("title ILIKE ?", "%#{params[:search].strip}%" ) unless params[:search].blank?
     @groups = @groups.where(user_id: current_user.id ) if params[:my_groups]
     @groups = @groups.page(params[:page]).per(10)
     
  end

  def show
    @group =Group.find(params[:id])
    authorize @group
  end
 
	def new
		@group = Group.new()
     authorize @group
	
	end


  def create
    authorize Group
    @group =Group.new(create_params)
    @group.user = current_user
    if @group.save
     
    else
       respond_to do |format|
         format.html { render action: "new" }
        end
    end
  end
  
  def edit
    
    @group =Group.find(params[:id])
    authorize @group, :update?
    
  end
  
  def update
    
    @group =Group.find(params[:id])
    authorize @group, :update?
    respond_to do |format|
      if ( @group.update(update_params))
       #  @group_memberships = @group.group_memberships.includes(:user).order("users.surname").page(params[:page]).per_page(10)
        format.html {redirect_to group_group_memberships_path(@group, animate: true), status: 303}
      else
        logger.debug "\n\n\render edit \n\n"
			  format.html { render action: "edit" }
      end
    end
   
    
  end

  
  

  def destroy
    @group = Group.find params[:id]
     authorize @group
    if @group.destroy
       redirect_to groups_path(), status: 303
    else
       flash.now.alert = error_message_on_delete_to_list(@group)
      respond_to do |format|
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end



 


  private
    def set_purpose
      @purpose = params[:purpose] || 'admin'
      if (@purpose =='happening')
        @happening = Happening.find params[:parent_id]
      end
    end
    

    
    def create_params
   safe_attributes =
     [:title
     ]
      
     params.require(:group).permit(*safe_attributes)
    end

    def update_params
   safe_attributes =
     [:delete_import,
      :clone_group,
      :user_id,
      :title ]
      
     params.require(:group).permit(*safe_attributes)
    end
end

