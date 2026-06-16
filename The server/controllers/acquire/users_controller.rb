class Acquire::UsersController < UsersController
  

  def update
     @user= User.find(params[:id])
     @user.assign_attributes(safe_params)
     @user.skip_reconfirmation! 
  #   authorize @user
     #  end
   
    if @user.save
    
       ActionCable.server.broadcast( "UsersChannel:list_users",{ className:"user_#{@user.id}",
       body: "small string" })
     
       redirect_to acquire_user_url(@user)
    else
      respond_to do |format|
        format.html { render  "edit" }
      end
    end
    
  end
end
