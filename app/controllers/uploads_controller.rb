class UploadsController < ApplicationController
  def new
    if Current.user.credit_balance == 0
      redirect_to new_payment_path, alert: "You need credits to upload journal pages. Buy some first!"
      return
    end
  end

  def create
    if Current.user.credit_balance == 0
      redirect_to new_payment_path, alert: "You need credits to upload journal pages."
      return
    end

    images = params[:images]
    orientation = params[:orientation] || "0"

    if images.blank?
      redirect_to new_upload_path, alert: "Please select at least one image."
      return
    end

    # Create transcription job
    job = Current.user.transcription_jobs.create!(
      status: :pending,
      page_count: images.count
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

    # Kick off the OCR pipeline
    OcrPipelineJob.perform_later(job.id)

    redirect_to dashboard_path, notice: "Uploaded #{images.count} page(s). Processing will begin shortly."
  end
end
