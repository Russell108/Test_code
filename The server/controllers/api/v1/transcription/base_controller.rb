# /app/controllers/api/v1/transcription/base_controller.rb
class Api::V1::Transcription::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_m4!
  
  private

  

  def authenticate_m4!
      auth_header = request.headers['Authorization']
      token = auth_header&.split(' ')&.last
    
      # Use a local variable to ensure we aren't calling bytesize on a nil credential
      expected_token = Rails.application.credentials.m4_api_token

      if expected_token.blank?
        Rails.logger.error "API Token missing in credentials.yml.enc"
        return render json: { error: "Server Configuration Error" }, status: :internal_server_error
      end

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
        # security by obscurity
       return render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
        # The 'return' is mandatory here to stop the 'index' action from firing
      #  return render json: { error: "Unauthorized" }, status: :unauthorized
      end
    
      # If we reach here, Rails continues to the actual controller action automatically
    end
end

