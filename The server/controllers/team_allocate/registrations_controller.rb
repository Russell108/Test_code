class TeamAllocate::RegistrationsController < ApplicationController
  include CustomerRender
  before_action :authenticate_user!
  before_action :load_and_authorize

  
  
   def new
      @group = @happening.attached_groups.find_by(user_id: current_user.id).group 
      logger.debug "\n\n@group #{@group.inspect}\n\n"
     @registration = @happening.registrations.new()
		 case  params[:team2import]  
 		  when "group" 
          @member_types= MbrType.all.where.not(name: 'Lapsed')
		   	  @member_title = "Group: " +  @group.title + " members" 
		  when "Current" 
          @member_types= MbrType.all.where.not(name: 'Lapsed')
		   	  @member_title ="Current Course Members"
		  when "Guest Course" 
          @member_types= MbrType.all.where(name: 'Guest')  
		   	  @member_title ="Current Course Guests"
		  when "Tutor Course" 
        @member_types= MbrType.all.where(name: 'Tutor')
		     @member_title =	"Current Course Tutors"
		  when "Student Course" 
        @member_types= MbrType.all.where(name: 'Student')
		    @member_title =	"Current Course Students"
		end 
    
     respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("registration_for_team", partial: "new") }
     end
   end
  
   def create
     logger.debug "\n\nTeamAllocate::RegistrationsController create\n\n"
     group = @happening.attached_groups.find_by(user_id: current_user.id).group rescue nil
     results =  @happening.process_team_registration( params[:team2import], create_params[:mbr_type_id],group)
     logger.debug "\n\nresults #{results}\n\n"
     flash[:notice]  = results[0]
     flash[:alert]  = results[1]
     
     redirect_to team_allocate_happening_customers_path(@happening, team2import: params[:team2import])

   end
  
   private
  
   def load_and_authorize
     @happening= Meet.find(params[:meet_id])
     authorize [:admin, @happening], :update?
   end
 
  
   def create_params
     safe_attributes =[ :mbr_type_id]
     params.require(:registration).permit(*safe_attributes)
   end
 end