class ApiController < ApplicationController

  def reload_csrf 
    render json: { csrf: form_authenticity_token }, status: :ok
  end

end