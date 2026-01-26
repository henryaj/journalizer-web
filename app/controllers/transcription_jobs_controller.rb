class TranscriptionJobsController < ApplicationController
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
end
