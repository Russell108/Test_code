# app/controllers/api/v1/tokens_controller.rb
module Api
  module V1
    class TokensController < Api::V1::Transcription::BaseController
      # We inherit from BaseController to ensure authenticate_m4! runs
      
      def show
        render json: { 
          csrf_token: form_authenticity_token 
        }
      end
    end
  end
end