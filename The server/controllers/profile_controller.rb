class ProfileController < ApplicationController
	before_action :authenticate_user!
  layout 'navbar_free'
     before_action do
       (params[:user] = safe_params)if params[:user]
     end
    def show
        logger.debug"\n\n tiemout in #{current_user.timeout_in}"
        if (current_user.id !=params[:id].to_i)
           raise ActiveRecord::RecordNotFound
           return
       else
           @user = (User.find params[:id]) 
       end
    
     
    end

    def edit
     
        if (current_user.id !=params[:id].to_i)
           raise ActiveRecord::RecordNotFound
        return
      else
           @user = (User.find params[:id]) 
      end
    end
    

     
    def update
         if (current_user.id !=params[:id].to_i)
           raise ActiveRecord::RecordNotFound
        return
      else
           @user = (User.find params[:id]) 
      end
     
        if @user.update(params[:user])
          render "show"
        else
          render "edit" 
        end
     
    end


    
    private
  
    def safe_params
      safe_attributes =
        [
          :forename,
          :surname,
          :email,
          :d_o_b,
          :family_mailings
        ]
     params.require(:user).permit(*safe_attributes)
    end


end

