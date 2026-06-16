class Import::GroupMembershipsController < ApplicationController
  
  before_action :authenticate_user! 
  
  
  
  def index
  
    authorize User
    @group =Group.find(params[:group_id])
    if( @group.import.attached?)
         load_collections_for_render
    #   respond_to do |format|
    #     format.html { logger.debug("\n\n we are html \n\n") }
    #   end
      else
   
        flash[:notice]= "Error."
        redirect_to group_group_memberships_path(@group)
      
      end
  end
  
  
  def create
    authorize User
     @group =Group.find(params[:group_id])
      @group.remove_emails = params[:group_membership][:group][:remove_emails]
      
      logger.debug("\n\n  @group.remove_emails #{ @group.remove_emails} \n\n")
     import_result = @group.check_in_import 
     flash.now[:notice] = "#{import_result[0]}  #{"person".pluralize(import_result[0])} imported"
     flash.now[:alert] = import_result[1].join("<BR>") unless import_result[1].blank?
     load_collections_for_render
   
  end
  
  private
  
  def load_collections_for_render
    @users = @group.process_csv_for_edit
    emails =  @users.collect(&:email)
    @duplicate_emails = emails.select { |e| emails.count(e) > 1 }
   
    @known_users = User.where(email:emails)
      .pluck(Arel.sql("users.email, ARRAY[users.id::text, CONCAT_WS(' ', users.forename, users.surname), users.archived::text]")).to_h
     
    @group_member_user_ids = @group.user_ids
   
    
  end
  
  def update_params
    safe_attributes =
      [ group_attributes: [:remove_emails]
      ]
       
      params.require(:group).permit(*safe_attributes) rescue {}
  end
  
  
  rescue_from ActiveStorage::FileNotFoundError do |exception|
   #  user.avatar.purge
     @group.import.purge
      message = ("
            <p>Sorry the CSV is no longer available.<BR>
              If necessary please import the CSV again").html_safe
      respond_to do |format|
        format.html { flash[:alert]= message
            redirect_to groups_path}
        format.turbo_stream {flash.now[:alert]= message
            render :template => '/shared/flash'}
        format.pdf {flash[:alert]= message
             redirect_to root_path}
      end
  
  end
end
