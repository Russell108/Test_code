class SponsorsController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_purpose
  

  
  def index
    logger.debug "\n\nrequest.headers['Turbo-Frame'] #{ request.headers["Turbo-Frame"] }\n\n"
    logger.debug "\\n\nparams[:search] #{params[:search]}\n\n"
    @sponsors = User.user_search_limit_search_to_2_strings(params[:search])
                .order(:surname)
               # .select_for_index
                .page(params[:page])

  end
  
  
  def show
    @sponsor = User.find params[:id]
  end
  
  def set_purpose
      @purpose = params[:purpose]
    end
end