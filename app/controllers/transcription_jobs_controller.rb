class TranscriptionJobsController < ApplicationController
  def review
    @job = Current.user.transcription_jobs.find(params[:id])

    unless @job.awaiting_review?
      redirect_to dashboard_path, alert: "This upload has already been reviewed."
      return
    end

    @pages = @job.job_pages.in_order.includes(image_attachment: :blob)
    @credit_balance = Current.user.credit_balance
  end

  def confirm
    @job = Current.user.transcription_jobs.awaiting_review.find(params[:id])

    # Update review settings
    @job.update!(
      date_parsing_enabled: params[:date_parsing_enabled] != "0",
      year_hint: params[:year_hint].presence&.to_i,
      reviewed_at: Time.current
    )

    # Process manual groupings if provided
    process_groupings(params[:groups]) if params[:groups].present?

    # Check credits and proceed
    if Current.user.has_credits?(@job.page_count)
      Current.user.deduct_credits!(@job.page_count, job: @job)
      @job.update!(status: :pending)
      OcrPipelineJob.perform_later(@job.id)
      redirect_to dashboard_path, notice: "Processing started for #{@job.page_count} page(s)."
    else
      @job.update!(status: :awaiting_credits)
      redirect_to dashboard_path, alert: "Insufficient credits. You have #{Current.user.credit_balance} but need #{@job.page_count}. Buy more to process."
    end
  end

  def destroy
    job = Current.user.transcription_jobs.find(params[:id])
    job.destroy
    redirect_to dashboard_path, notice: "Upload deleted."
  end

  def process_partial
    job = Current.user.transcription_jobs.awaiting_credits.find(params[:id])
    available = Current.user.credit_balance

    if available == 0
      redirect_to dashboard_path, alert: "You need at least 1 credit to process."
      return
    end

    original_page_count = job.page_count
    pages_to_process = [available, original_page_count].min

    job.process_with_partial_credits!(available)

    redirect_to dashboard_path, notice: "Processing #{pages_to_process} of #{original_page_count} pages."
  end

  private

  def process_groupings(groups_param)
    # groups_param format: { "0" => ["1", "2"], "1" => ["3"] }
    # Keys are group numbers, values are arrays of page_numbers
    groups_param.each do |group_num, page_numbers|
      page_numbers = Array(page_numbers).map(&:to_i)
      next if page_numbers.size <= 1 # Single pages don't need explicit groups

      group = @job.page_groups.create!(group_number: group_num.to_i)
      @job.job_pages.where(page_number: page_numbers).update_all(page_group_id: group.id)
    end
  end
end
