class AccountController < ApplicationController
  before_action :require_authentication

  def show
    @transactions = Current.user.page_credits.order(created_at: :desc).limit(50)
  end

  def update
    if Current.user.update(user_params)
      redirect_to account_path, notice: "Settings saved."
    else
      redirect_to account_path, alert: "Could not save settings."
    end
  end

  private

  def user_params
    params.require(:user).permit(:entry_retention, :email_preference)
  end
end
