class AccountController < ApplicationController
  before_action :require_authentication

  def show
    @transactions = Current.user.page_credits.order(created_at: :desc).limit(50)
  end
end
