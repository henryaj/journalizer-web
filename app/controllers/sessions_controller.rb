class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create dev_login ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  def dev_login
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?

    user = User.find_by(email_address: "dev@example.com")
    if user
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Dev user not found. Run `rails db:seed` first."
    end
  end
end
