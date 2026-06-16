class TalkTypesController < ApplicationController
   
	   before_action :authenticate_user!
  	#  To List talk types to manage accesses ie self referencing relationship used to access resources & packages etc  
    # CRUD By SIte admin




	# ==============================================================================================================
 

	def index
    authorize TalkType
		@talk_types =TalkType.all
    @accesses_grouped_by_talk_type = Access.grouped_by_talk_type
    @flash_delay = 8000
  end

  def show
    authorize TalkType
  end
  
  def new
     authorize TalkType
     logger.debug "\n\nauthorized\n\n"
     @talk_type = TalkType.new
  end
  
	def create
  
		@talk_type = TalkType.new(safe_params)
     authorize [  @talk_type]
		
		  if @talk_type.save
        @talk_types =TalkType.all
         @accesses_grouped_by_talk_type = Access.grouped_by_talk_type
		  else
		     render action: "new" 
		  end
   
 	end
  
	def edit
		
	end
  
  


  def destroy
    @talk_type = TalkType.find params[:id]
     authorize [@talk_type]
    if @talk_type.destroy
      flash[:notice] = "The family Group '#{@talk_type.name}' succssfully removed"
         redirect_to talk_types_path
      
      
    else
       flash[:alert] = error_message_on_delete_to_list(@talk_type)
         redirect_to talk_types_path
       
     
    end
  end

	private
	#  ========   private methods.    ================================

	
	def safe_params
  		safe_attributes =[
  					:name]
 		
		params.require(:talk_type).permit(*safe_attributes)
	end

end
