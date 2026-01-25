class CamerasController < ApplicationController
  def show
    if Current.user.credit_balance == 0
      redirect_to new_payment_path, alert: "You need credits to capture journal pages. Buy some first!"
      return
    end
  end
end
