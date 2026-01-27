class AccountController < ApplicationController
  def show
    @transactions = Current.user.page_credits.order(created_at: :desc).limit(50)
  end
end
