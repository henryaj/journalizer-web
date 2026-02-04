class RetryStuckJobsJob < ApplicationJob
  queue_as :default

  STUCK_THRESHOLD = 30.minutes

  def perform
    retried_count = 0

    # Find jobs stuck in processing states
    stuck_jobs = TranscriptionJob
      .where(status: %w[processing post_processing])
      .where("updated_at < ?", STUCK_THRESHOLD.ago)

    stuck_jobs.find_each do |job|
      case job.status
      when "processing"
        # Re-check OCR progress - this will either continue polling or trigger post-processing
        CheckOcrProgressJob.perform_later(job.id)
        Rails.logger.info "RetryStuckJobsJob: Re-enqueued CheckOcrProgressJob for job #{job.id} (stuck in processing)"

      when "post_processing"
        # Retry post-processing with Claude
        PostProcessJob.perform_later(job.id)
        Rails.logger.info "RetryStuckJobsJob: Re-enqueued PostProcessJob for job #{job.id} (stuck in post_processing)"
      end

      retried_count += 1
    end

    Rails.logger.info "RetryStuckJobsJob: Retried #{retried_count} stuck jobs" if retried_count > 0
  end
end
