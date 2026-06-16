class Acquire::AcquireshipsController < ApplicationController
  include  AdminAcquisitionRender
  before_action :authenticate_user! 
  before_action :load_and_authorize
  

  ##########################       controller actions.     #######################################
  
	def index
   # @controller_first_namespace ||="acquire"
    @active_tab = 'acquireships'
    logger.debug "\n\n@attached_group #{@attached_group.inspect}\n\n"
    #find all people who have acquired a package or recording from happening
    @animate= false
    @team ||= "acquirees"
    load_collections_for_team_acquisition_render(@happening, current_user, @team)
    unless( params.has_key? :full_page)
       logger.debug "\n\n false params.has_key? :full_page false)\n\n"
     respond_to do |format|
        format.turbo_stream{render  "_index" }
        format.html{ }
     end
    end
	end
  
  def show
     @animate = (params.has_key? :animate) ?  true : false
 #   @acquired_package=  @happening.acquired_packages.find params[:id]
     @user =User.find params[:id]
     load_collections_for_acquisition_render( params[:id], @happening)
  end
  
  
  def create
    @animate = (params.has_key? :animate) ?  true : false
    @user =User.find params[:user_id]
    load_collections_for_acquisition_render( @user.id, @happening)
  end
  
  
  
  ####################### private methods   ############################################
   private
 

  def load_and_authorize
    @happening= Happening.find(params[:happening_id])
    authorize [:admin, @happening], :update?
  end
end

