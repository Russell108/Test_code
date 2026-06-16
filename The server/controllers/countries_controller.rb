class CountriesController < ApplicationController
  
  before_action :set_country, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!
  

	def index
	   @countries = Country.all.order("name").page(params[:page]).per(20)
     authorize Country
	end

  def show
    authorize @country
  end

 
  def new
    @country = Country.new
    authorize @country
  end

 
  def create
    @country = Country.new(country_params)
    authorize @country
    respond_to do |format|
      if @country.save
        format.turbo_stream { }
      else
        format.html { render :new }
      end
    end
  end

  def edit
    authorize @country
    
  end
  
  def update
    authorize @country
   
      if @country.update(country_params)
        render turbo_stream: turbo_stream.replace("country_#{@country.id}", @country ) 
      else
        render :edit
      end
   
  end
  
  def destroy
    authorize @country
    if @country.destroy
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("country_#{@country.id}", @country )}
      end
    else
      respond_to do |format|
        flash.now.alert = error_message_on_delete_to_list(@country)
        format.turbo_stream{render  turbo_stream: turbo_stream.update("flash_messages", partial: "shared/flash") }
      end
    end
   end
   
 
  private
 
    # Use callbacks to share common setup or constraints between actions.
    def set_country
      @country = Country.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def country_params
      params.require(:country).permit(:name)
    end
end
