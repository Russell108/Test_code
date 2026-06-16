
module LockableController
  extend ActiveSupport::Concern

   included do
  #   before_action :set_twit, only: [:show, :edit, :destroy, :update]
     before_action :ensure_unlocked, only: [ :edit, :destroy, :update]
   end
#
#  def index
#    @twits = Twit.all
#  end
#
#  def new
#    @twit = Twit.new
#  end
#
#  def show
#  end
#
#  def create
#    @twit = Twit.new(twit_params)
#    if @twit.save
#      flash[:notice] = "Successfully created twit."
#      redirect_to @twit
#    else
#      flash[:alert] = "Error creating twit."
#      render :new
#    end
#  end
#
  private
  
  def ensure_unlocked
# # raise LockError,"This object is Locked to prevent editing and deletion of 'Mature Resources'.<BR> 
# #  If you still need to edit the item please email support with your requirements  support@drusound.com ".html_safe
# #  # render a flash message inviting contact with support
#   flash[:alert] =  ("Mature Resources are Locked to prevent accidental editing and deletion.<BR> 
#   If you  feel you need to edit the item please email support with your requirements  support@drusound.com ").html_safe
#    respond_to do |format|
#      format.html { }
#    end
  end

#  def twit_params
#    params.require(:twit).permit(:tweet)
#  end
#
#  def set_twit
#    @twit = Twit.find(params[:id])
#  end
end

