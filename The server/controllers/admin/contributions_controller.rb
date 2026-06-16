class Admin::ContributionsController < ApplicationController
  before_action :authenticate_user! 
  before_action :load_and_authorize
  

  
  def index
    logger.debug "\n\n index for listing contributions for happening\n\n"
    
    @contributors_for_recording= Speaker.speakers_for_recordings_render(@recording.id) rescue {}
    @current_speakers= Speaker.joins(contributions: :recording)
                    .where("recordings.happening_id =?", @happening.id).distinct
                    .order('speakers.surname ASC')
  end
  
#  def new
#    @contributions = @recording.contributions.includes(:speaker).group_by{|c|c.main}.to_h
#     @contribution = @recording.contributions.new 
#  end
  
  def create

    @contribution = @recording.contributions.new create_params
    respond_to do |format|
      if @contribution.save
        @contribution = Contribution.includes(:speaker).find(@contribution.id)
        format.html { }
        format.turbo_stream { }
      else
        flash.now[:alert] = (@contribution.errors.full_messages.join("<BR>")).html_safe
        format.html { }
       format.turbo_stream { render :template => 'shared/flash'}
      end
    end
  end
  
  


  def destroy
    @contribution= @recording.contributions.where(id: params[:id]).first
    
    if @contribution.destroy
      respond_to do |format|
        format.turbo_stream {  }
      end
    else
      flash.now.alert = error_message_on_delete_to_list(@contribution)
      respond_to do |format|
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  private
 
  
  def load_and_authorize
    @recording =Recording.find params[:recording_id] if params[:recording_id]
    @happening = @recording.happening
    authorize [:admin, @happening], :update?
  end
  
  def create_params
  	return unless params[:contribution]
  	
  		safe_attributes =[
        :main,
        :speaker_id
      ]
  	params.require(:contribution).permit(*safe_attributes) 
  end
end
