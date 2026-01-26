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
    has_enough_credits = Current.user.has_credits?(page_count)

    # Create transcription job with appropriate status
    job = Current.user.transcription_jobs.create!(
      status: has_enough_credits ? :pending : :awaiting_credits,
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

    if has_enough_credits
      # Kick off the OCR pipeline
      OcrPipelineJob.perform_later(job.id)
      redirect_to dashboard_path, notice: "Uploaded #{page_count} page(s). Processing will begin shortly."
    else
      redirect_to dashboard_path, alert: "Uploaded #{page_count} page(s) but you only have #{Current.user.credit_balance} credits. Buy more to start processing."
    end
  end
end
