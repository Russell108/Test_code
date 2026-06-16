class VenuesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_purpose, except: [:destroy]
  include LockableController
   
 
  def index
    @venue_search =VenueSearch.new(search_params)
    @venues = @venues = Venue.order(:name).includes(:happenings, :lock, :country)
    if !@venue_search.search.blank?
       @venues = @venues.where("name ILIKE ?", "%#{@venue_search.search}%")
    end
     @venues  = @venues.page(params[:page]).per(20)  
  
  end
   

	def show
      @scrollTo=true 
      @animate = true
		@venue = Venue.find(params[:id])
     authorize [ :admin, @venue]
  #  @versions = @venue.versions.reverse if params[:versions]
	 # respond_to do |format|
	 #
   #   logger.debug "\n\n@venues #{@venues}\n\n"
   #     format.turbo_stream{ render turbo_stream: turbo_stream.replace("venue_#{@venue.id}", @venue ) }
   #     format.html
   #   end
	end

	def new
		  @venue = Venue.new()
     authorize [ :admin, @venue]
      logger.debug "\n\n@purpose #{@purpose}\n\n"
		respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("new_venue", template: "/venues/new") }
      format.html         { }
		end
	end

	def create
		@venue = Venue.new(safe_params)
     authorize [ :admin, @venue]
		respond_to do |format|
		  if @venue.save
          @animate =true
		    format.turbo_stream {  }
		   
		  else
		    format.html { render action: "new" }
		  end
		end
 	end

	def edit
    @venue = Venue.find params[:id]
     authorize [ :admin, @venue]
		
	end

	def update
    @venue = Venue.find params[:id]
     authorize [ :admin, @venue]
		respond_to do |format|
			if @venue.update(safe_params)
          @animate =true
        logger.debug "\n\n@venues #{@venues}\n\n"
         format.turbo_stream{ redirect_to venue_path(@venue), scrollTo: true, animate:true}
         # format.turbo_stream{ render turbo_stream: turbo_stream.replace("venue_#{@venue.id}", @venue ) }
         # format.html
			else
			  format.html { render action: "edit" }
			end
		end
	end

  def destroy
    @venue = Venue.find params[:id]
     authorize [ :admin, @venue]
    if @venue.destroy
       respond_to do |format|
         format.turbo_stream { render turbo_stream: turbo_stream.remove("venue_#{@venue.id}" ) }
       end
    else
       flash.now.alert = error_message_on_delete_to_list(@venue)
      respond_to do |format|
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
  end
  
  private
  
  
  def search_params
    if( params.has_key?( :venue_search) )
    safe_attributes =
      [:purpose,
        :search
      ]
      params.require(:venue_search).permit(*safe_attributes)
      
    end
  end

	def safe_params
		safe_attributes =[  :name,:notes,:country_id]
		params.require(:venue).permit(*safe_attributes)
 	end

  def set_purpose
    @purpose = params[:purpose] || 'admin'
  end
end
