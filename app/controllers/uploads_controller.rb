class UploadsController < ApplicationController
  def new
    # Allow viewing the upload form even with low credits, just warn them
    @credit_warning = Current.user.credit_balance == 0
  end

  def create
    images = params[:images]
    orientation = params[:orientation] || "0"
    year_hint = params[:year].presence&.to_i

    if images.blank?
      redirect_to new_upload_path, alert: "Please select at least one image."
      return
    end

    page_count = images.count

    # Create transcription job in awaiting_review status
    job = Current.user.transcription_jobs.create!(
      status: :awaiting_review,
      page_count: page_count,
      year_hint: year_hint
    )

    # Create job pages with attached images
    images.each_with_index do |image, index|
      page = job.job_pages.create!(
        page_number: index + 1,
        status: :pending,
        orientation: orientation.to_i
      )
      page.image.attach(image)
    end

    # Redirect to review page where user can configure groupings and date parsing
    redirect_to review_transcription_job_path(job)
  end
end
