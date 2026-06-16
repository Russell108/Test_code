class SpeakersController < ApplicationController
	before_action :authenticate_user!
  before_action :authorize_user, except: [:index]
  before_action :set_index_params, omly: :index
  before_action :set_purpose, except: [:destroy]
  before_action :log_purpose

	def index
		
                                      
		@speakers = Speaker.select("speakers.*, reverse(split_part(reverse(speakers.stage_name), ' ', 1)) AS lastname")
                .order('lastname ASC')
							.includes(avatar_attachment: :blob)
		  					.page(params[:page]).per(15)
    user_ids = @speakers.collect(&:user_id).reject(&:blank?)
    @users=  User.pluck_for_speaker_render(user_ids).to_h
		unless params[:search].blank?   
			string= params[:search].split
           
			if string.size > 1
			     @speakers = @speakers.split_by_any_name(string[0], string[1])
			else
			   @speakers = @speakers.by_any_name(string[0])
			end
		end	
	end

	def show
    @purpose="admin"
		@speaker = Speaker.find params[:id]
    user= (User.pluck_for_speaker_render(@speaker.user_id).to_h rescue nil)
    @animate =true
    respond_to do |format|
      format.turbo_stream{ render turbo_stream: turbo_stream.replace("speaker_#{@speaker.id}", partial:'speaker', 
      locals:{speaker: @speaker, user: user, purpose: @purpose} ) }
      format.html{}
    end
    
  end

	def new
		@speaker = Speaker.new
		
	end

	def create
    @animate =true
		@speaker = Speaker.new(create_params)
		respond_to do |format|
		  if @speaker.save
        @user= (User.pluck_for_speaker_render(@speaker.user_id).to_h rescue nil)
		  	format.turbo_stream {   }
		  else
		    format.html { render action: "new" }
		  end
		end
 	end

	def edit
    
		@speaker = Speaker.find params[:id]
		respond_to do |format|
      format.turbo_stream {  render turbo_stream: turbo_stream.replace("speaker_#{@speaker.id}", template: "/speakers/edit") }
		  format.html { }
		  
		end
	end

	def update
   
		@speaker = Speaker.find params[:id]
     user= (User.pluck_for_speaker_render(@speaker.user_id).to_h rescue nil)
    if(params.has_key? :remove_avatar)
      @speaker.avatar.purge
     
      respond_to do |format|
        @animate =true
        format.turbo_stream{ render turbo_stream: turbo_stream.replace("speaker_#{@speaker.id}", partial: "speaker",
        locals:{speaker: @speaker,user: user} ) }
  	    format.html { redirect_to action: "show", search: params[:search] 
  	    }
      end
    else
		  
		  	logger.debug "\n\n update_params #{update_params.inspect}\n\n"
		  	if @speaker.update(update_params)
          
		  	  redirect_to action: "show", search: params[:search] 
          
		  	else
          respond_to do |format|
          format.turbo_stream {  render turbo_stream: turbo_stream.replace("speaker_#{@speaker.id}", template: "/speakers/edit") }
		  	  format.html { render action: "edit" }
            end
		  	end
		
    end
	end

	def destroy
    @speaker = Speaker.find params[:id]
      if @speaker.destroy
        redirect_to speakers_path
        else
          flash.now[:alert] =  ("<H6>This speaker cannot be deleted for the following reasons:</H6>" + 
                             @speaker.errors.full_messages.join("<BR>")).html_safe
           respond_to do |format|
             format.html { }
              format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
           end

        end
	end
  
  

  private
  
  rescue_from ActionController::InvalidAuthenticityToken, with: :alert_csrf
  
  def log_purpose
    logger.debug "\n\n @purpose =  #{@purpose}\n\n"
  end
  
  def error_csrf
      if (action_name == "update")
        redirect_to action: "edit"
      elsif (action_name == "create")
        redirect_to action: "new"
      end
      
  end
  

  def set_purpose
    @purpose = params[:purpose] || ''
    logger.debug  "purpose #{@purpose}"
  end
  
  def authorize_user
    
    authorize Speaker
  end

	def create_params
		safe_attributes =[  :title,
							:forename,
							:surname,
							:notes,
							:stage_name,
							:user_id
						]
		params.require(:speaker).permit(*safe_attributes)
 	end

	def update_params
		safe_attributes =[:title,
							:forename,
							:surname,
							:notes,
							:stage_name,
						 	:avatar,
              :user_id,
							:crop_x,:crop_y, :crop_w,:crop_h,
              :zoom,
              :orientation
             ]
		params.require(:speaker).permit(*safe_attributes)
  end
	
  def set_index_params
    @safe_search_params = {parent_id: params[:parent_id], purpose: params[:purpose], search: params[:search] } rescue {}
    logger.debug "\n\n@safe_search_params #{@safe_search_params}\n\n"
  end
end
