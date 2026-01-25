class ApiTokensController < ApplicationController
  before_action :require_authentication

  def index
    @tokens = Current.user.api_tokens.active.order(created_at: :desc)
    @new_token = flash[:new_token]  # Only shown once after creation
  end

  def create
    @token = Current.user.api_tokens.create!(
      name: params[:name].presence || "API Token",
      expires_at: params[:expires_at].presence
    )

    # Store raw token in flash to show once
    flash[:new_token] = @token.raw_token
    redirect_to api_tokens_path, notice: "Token created. Copy it now - it won't be shown again."
  end

  def destroy
    @token = Current.user.api_tokens.find(params[:id])
    @token.revoke!
    redirect_to api_tokens_path, notice: "Token revoked."
  end
end
