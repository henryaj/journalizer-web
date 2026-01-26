class PostProcessJob < ApplicationJob
  queue_as :post_process

  retry_on Anthropic::RateLimitError, wait: 5.seconds, attempts: 5 if defined?(Anthropic::RateLimitError)
  retry_on Anthropic::APIError, wait: :polynomially_longer, attempts: 3 if defined?(Anthropic::APIError)
  discard_on ActiveRecord::RecordNotFound

  def perform(job_id)
    job = TranscriptionJob.find(job_id)
    return if job.completed? || job.failed?

    job.mark_post_processing!

    # Collect raw text from all completed pages
    raw_texts = job.job_pages
      .where(status: :ocr_complete)
      .in_order
      .map { |p| "--- Page #{p.page_number} ---\n#{p.raw_ocr_text}" }
      .join("\n\n")

    # Process with Claude Haiku
    processor = ClaudePostProcessor.new
    entries_data = processor.process(raw_texts, page_count: job.page_count, year_hint: job.year_hint)

    # Create journal entries
    entries_data.each do |entry_data|
      entry = job.journal_entries.create!(
        user: job.user,
        title: entry_data[:title],
        entry_date: entry_data[:date],
        content: entry_data[:text],
        date_detected: entry_data[:date].present?,
        image_indices: entry_data[:image_indices] || []
      )

      # Attach relevant images
      attach_images_to_entry(entry, job, entry_data[:image_indices])
    end

    job.mark_completed!

    # Could notify user via email here
    Rails.logger.info "Job #{job.id} completed: #{entries_data.size} entries created"

  rescue => e
    job.mark_failed!(e.message)
    Rails.logger.error "PostProcessJob failed for job #{job_id}: #{e.message}"
    raise
  end

  private

  def attach_images_to_entry(entry, job, indices)
    # If no indices specified, attach all images
    indices = (0...job.page_count).to_a if indices.blank?

    indices.each do |idx|
      page = job.job_pages.find_by(page_number: idx)
      next unless page&.image&.attached?

      # Copy blob to entry's images
      entry.images.attach(page.image.blob)
    end
  end
end
