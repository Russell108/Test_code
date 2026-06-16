class User::ResourcesController < ApplicationController

	before_action :authenticate_user!

 prepend_before_action   :skip_timeout, only: [:show]
 
 
  def show
    logger.debug "\n\n client requested to download a file redirected to show action\n\n"
   @resource = policy_scope([:user, Resource]).find(params[:id])
  # logger.debug "\n\n @resource #{@resource.inspect}\n\n"
 #  logger.debug "\n\n @resource #{@resource.available_for_download}\n\n"
   unless @resource.available_for_download[0]
     message = "At this time the resource is not available.\n" +
     "The support team have been informed, will investigate and get back to you. Thank you".html_safe
     resource = Resource.find( params[:id]) rescue params[:id].to_i 
     SupportMailer.missing_resource(current_user, resource, "Not available in Database" ).deliver_later
     respond_to do |format|
       format.turbo_stream{
         flash.now[:alert] =message
         render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
     end
  		return
   end
   logger.debug "\n\n@resource.available_for_download\n\n" 
   @download_url_array =@resource.available_for_download
   respond_to do |format|
     format.html{ redirect_to user_happening_path(@resource.recording.happening_id)}
     format.turbo_stream{logger.debug "\n\n render turbo stream\n\n" }
   end
  end
 
	def update
   redirect_to action: :show
   return
   #ActiveStorage::FileNotFoundError < ActiveStorage::Error
   logger.debug "\n\n client requested to download a file\n\n"
   @resource = policy_scope([:user, Resource]).find(params[:id])
   #logger.debug "\n\n #{@resource.inspect}\n"
		# if resource not available to user show error message & send email to support
		#  send email user does not have access to requested resource
   unless @resource
     logger.debug "\n\n no resource \n\n"
			
     flash[:alert] = "At this time the resource is not available.\n" +
     "The support team have been informed, will investigate and get back to you. Thank you".html_safe
     resource = Resource.find( params[:id]) rescue params[:id].to_i 
     SupportMailer.missing_resource(current_user, resource, "Not available in Database" ).deliver_later
     respond_to do |format|
       format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
     end
			return
   end
   logger.debug "\n\n resource in database\n\n"
   # file can of been uploaded manually or by active storage if  missing on storage 
   # email support and show alert to client
		unless  @resource.file.attached?
			flash[:alert] = "At this time the resource is not available.\n" +
     "The support team have been informed, will investigate and get back to you. Thank you!".html_safe
     SupportMailer.missing_resource(current_user, @resource, "Not available at Amazon S3").deliver_later
			respond_to do |format|
       format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
     end
			return
		end
   respond_to do |format|
     format.html{ redirect_to user_happening_path(@resource.recording.happening_id)}
     format.turbo_stream{logger.debug "\n\n render turbo stream\n\n" }
   end
	end


  private
    
  def skip_timeout
    request.env["devise.skip_trackable"] = true
    request.env["devise.skip_timeout"] = true
  end
  
  rescue_from ActiveRecord::RecordNotFound do |exception|
    message = ("<p>Sorry we could not find the thing #{action_name}<BR> if you think this is an error please email us at: support at drusound.com.").html_safe
    
    flash[:alert] = "At this time the resource is not available.\n" +
    "The support team have been informed, will investigate and get back to you. Thank you".html_safe
    resource =  params[:id].to_i 
    SupportMailer.missing_resource(current_user, resource, "Not available in Database" ).deliver_later
    respond_to do |format|
      format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash",locals:{delay: 8000}) }
    end
  end

  
end




