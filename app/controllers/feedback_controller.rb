class FeedbackController < ApplicationController
  def create
    message = params[:message]&.strip

    if message.present?
      FeedbackMailer.submit(Current.user, message).deliver_later
      render turbo_stream: turbo_stream.replace("feedback_widget", partial: "feedback/success")
    else
      head :unprocessable_entity
    end
  end
end
