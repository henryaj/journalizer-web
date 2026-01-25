module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods

      before_action :authenticate_api_token!
      before_action :check_rate_limit

      private

      def authenticate_api_token!
        authenticate_or_request_with_http_token do |token, _options|
          @api_token = ApiToken.authenticate(token)
          @current_user = @api_token&.user

          @api_token&.touch(:last_used_at) if @api_token
          @current_user.present?
        end
      end

      def current_user
        @current_user
      end

      def check_rate_limit
        key = "api_rate_limit:#{current_user&.id || request.remote_ip}"
        count = Rails.cache.increment(key, 1, expires_in: 1.minute)

        if count.to_i > 60  # 60 requests per minute
          render json: { error: "Rate limit exceeded" }, status: :too_many_requests
        end
      end

      def render_error(message, status: :bad_request)
        render json: { error: message }, status: status
      end
    end
  end
end
