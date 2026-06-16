class ActivationsController < ApplicationController

  # this controller is used for sending  activation reminders to people 

  # used to display form to search for an account & verify its status
  # from the home page
    def index
            @user_search =UserSearch.new index_params
        if ((params.has_key? :user_search)  && @user_search.valid? )
            @user= @user_search.user

           
            if (!@user.confirmed?)  
               @status = "needs_activation" 
            elsif (@user.pending_reconfirmation?)
               @status = "unconfirmed"
            else
                @status ="valid_for_login"
                flash[:notice]= "We checked your account and its all upto date. <BR>
                    Your are good to Login".html_safe
                redirect_to root_path and return
            end
        end
    end

  def show
 
  end

	def new
    #  user is confirming their email address from an email sent to them
    # find the user by their confirmation code
		@user =User.find_by_confirmation_token(params[:confirmation_token])
    logger.debug "\n\n@user #{@user.inspect}\n\n"
    (logger.debug "\n\n@user.confirmation_token_current? #{@user.confirmation_token_current?.inspect}") if @user
    if @user
      if @user.confirmation_token_current?
        logger.debug "\n\n@user.confirmation_token_current?"
        @activation = Activation.new(token: @user.confirmation_token )
         logger.debug "\n\n@@activation #{@activation.inspect}\n\n"
      else
          flash.now[:alert] =  ("Your confirmation token has expired.<BR> 
        Please contact the support department or request a new confirmation email from the link:<BR><BR>" + 
        view_context.link_to( "Request new confirmation email", 
				new_user_confirmation_path(), class:"btn btn-outline-primary ")).html_safe
      end
    else
      flash.now[:alert] =  ("Sorry we could not recognise your account, from the confirmation code.<BR> 
          You could try again or<BR>  Please close this message and request a new confirmation email from the link or<BR>" + 
          "contact the support department sales@drusound.com").html_safe
    end


	end

  def create
     
        # user is activating their account
        # check validity & currentness of confirmation token
        # has user agreed 
        # does user want a email reset
      
        
    if (@user =User.find_by_confirmation_token(params[:activation][:token]))
      logger.debug "\n\n@user #{@user.inspect}\n\n"
      logger.debug "\n\n@user.confirmation_token_current? #{@user.confirmation_token_current?}"
      # if user not init_agree then need to ensure creation & validation of password
      @activation = Activation.new(create_params )
       # if user not init_agree then need to ensure creation & validation of password 
        @activation.init_agree =@user.init_agree
        @activation.forename = @user.forename
        @activation.surname =  @user.surname
        @activation.email =  @user.email
        @user.password =@activation.password
        @user.password_confirmation =@activation.password_confirmation
         @user.d_o_b =@activation.d_o_b
         logger.debug "\n\n line 77 @activation.valid? #{@activation.valid?}\n\n"
          
      if @activation.valid?
            @user.init_agree =Date.today
            logger.debug "\n\n@@activation.valid\n\n"
        if @user.confirm
          @user.save
          logger.debug "\n\n@user.save\n\n"
          @user.send_reset_password_instructions if @activation.reset_password
          
                              
        else
          flash.now[:alert] =  ("Your confirmation token has expired.<BR> 
        Please contact the support department or request a new confirmation email from the link:<BR><BR>" + 
        view_context.link_to( "Request new confirmation email", 
				new_user_confirmation_path(), class:"btn btn-outline-primary ")).html_safe
           end
      else
       logger.debug "\n\n line 96 @activation.errors #{@activation.errors.full_messages}\n\n"
           
              render action: "new"
              return
      end
 
  
    else
      flash[:alert] =  ("We could not recognise your account, from the confirmation code.<BR> 
          Please contact the support department or:<BR><BR>" + 
          "request a new confirmation email from the link").html_safe
           render action: "new"
    end
  end	

  
  private

  def create_params
        safe_attributes =[  :token,:agreement, :reset_password, :password, :password_confirmation, :d_o_b,]
        params.require(:activation).permit(*safe_attributes)
    end

    def index_params
             safe_attributes =[  :email]
        params.require(:user_search).permit(*safe_attributes) if params[:user_search]
    end
    
 

  
end
