class BucketsController < ApplicationController
  
	before_action :authenticate_user!

  

  
	def index
	   @buckets = Bucket.all.order("name")
     authorize Bucket
	end
  
	def show
	    @bucket = Bucket.find(params[:id])
     authorize@bucket
	  
	end
  
  def new
    @bucket = Bucket.new
    authorize @bucket
		
  end

  def create
    @bucket = Bucket.new(safe_params)
    authorize @bucket
   
      if @bucket.save
       @animate = true
      else
        render   :new 
      end
   
  end
  
  
  def edit
    @bucket = Bucket.find(params[:id])
    authorize @bucket
  end
  
  
  def update
    @bucket = Bucket.find(params[:id])
    authorize @bucket
   
      if @bucket.update(safe_params)
        @animate = true
        render turbo_stream: turbo_stream.replace("bucket_#{@bucket.id}", @bucket ) 
      else
        render :edit
      end
  end

 
 
  def destroy
    @bucket=Bucket.find(params[:id]) 
      authorize @bucket
       if   @bucket.destroy
         respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.replace("bucket_#{@bucket.id}", @bucket ) }
         
         end
       else
         respond_to do |format|
           flash.now.alert = error_message_on_delete_to_list(@bucket)
            logger.debug "\n\n@bucket @bucket #{@bucket.id}\n\n"
           format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
         end
       end
   end
  
  private

  def safe_params
    safe_attributes = [:name,
                       :region_id,
                       :credential_prefix,
                       :aws_account_endpoint_id,
                       :aws_subdomain_endpoint_id]
    params.require(:bucket).permit(*safe_attributes)
  end
end
