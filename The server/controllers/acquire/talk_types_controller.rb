class Acquire::TalkTypesController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_user!
  
  
  def index
    @talk_types = TalkType.all.includes(accesses: :access_type)
  end
  
  def show
    @group= params[:group]
	  @talk_type=TalkType.find params[:id]
		if (@group== "all")
			talk_type_ids= Access.where(access_type_id:  @talk_type.id).pluck("talk_type_id")
      logger.debug "\n\ntalk_type_ids= #{talk_type_ids} \n\n"
			@users= User.where(talk_type_id: talk_type_ids).order("users.surname")
		else
			@users = @talk_type.users.order("users.surname")
						
		end
    @users =@users.page(params[:page]).per(30) unless params[:email]      # add 30 per_page
  end
  
  def authorize_user!
     authorize [:acquire, TalkType]
  end
    
end
