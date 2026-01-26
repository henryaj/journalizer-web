class JobPagesController < ApplicationController
  before_action :require_authentication

  def rotate
    job = Current.user.transcription_jobs.awaiting_review.find(params[:transcription_job_id])
    page = job.job_pages.find(params[:id])

    # Cycle through orientations: 0 -> 90 -> 180 -> 270 -> 0
    new_orientation = (page.orientation + 90) % 360
    page.update!(orientation: new_orientation)

    render json: { orientation: new_orientation }
  end
end
