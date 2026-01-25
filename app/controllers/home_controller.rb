class HomeController < ApplicationController
  allow_unauthenticated_access

  def index
    if authenticated?
      redirect_to dashboard_path
    end
  end
end
