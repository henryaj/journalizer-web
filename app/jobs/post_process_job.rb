class PostProcessJob < ApplicationJob
  queue_as :post_process

  retry_on Anthropic::RateLimitError, wait: 5.seconds, attempts: 5 if defined?(Anthropic::RateLimitError)
  retry_on Anthropic::APIError, wait: :polynomially_longer, attempts: 3 if defined?(Anthropic::APIError)
  discard_on ActiveRecord::RecordNotFound

  def perform(job_id)
    job = TranscriptionJob.find(job_id)
    return if job.completed? || job.failed?

    job.mark_post_processing!

    if job.has_manual_groups?
      # User manually grouped pages - each group becomes one entry
      process_grouped_pages(job)
    elsif job.date_parsing_enabled?
      # Original behavior - let Claude split by date
      process_with_date_detection(job)
    else
      # No groups, no date parsing - each page is one entry
      process_individual_pages(job)
    end

    job.mark_completed!
    Rails.logger.info "Job #{job.id} completed: #{job.journal_entries.count} entries created"

    send_entry_notifications(job)

  rescue => e
    job.mark_failed!(e.message)
    Rails.logger.error "PostProcessJob failed for job #{job_id}: #{e.message}"
    raise
  end

  private

  def process_grouped_pages(job)
    processor = ClaudePostProcessor.new

    # Process each explicit group
    job.page_groups.in_order.each do |group|
      pages = group.job_pages.where(status: :ocr_complete).in_order

      combined_text = pages
        .map { |p| "--- Page #{p.page_number} ---\n#{p.raw_ocr_text}" }
        .join("\n\n")

      if job.date_parsing_enabled?
        # Process with Claude but force single entry
        entries_data = processor.process(
          combined_text,
          page_count: pages.count,
          year_hint: job.year_hint,
          force_single_entry: true
        )
      else
        # No AI processing, just clean up text
        entries_data = [{
          title: generate_title_from_text(combined_text),
          text: clean_ocr_text(combined_text),
          date: nil,
          image_indices: pages.pluck(:page_number)
        }]
      end

      create_entries_from_data(job, entries_data, pages)
    end

    # Process ungrouped pages individually
    ungrouped_pages = job.job_pages.where(page_group_id: nil, status: :ocr_complete).in_order
    ungrouped_pages.each do |page|
      process_single_page(job, page, processor)
    end
  end

  def process_with_date_detection(job)
    # Original behavior - collect all text and let Claude split by date
    raw_texts = job.job_pages
      .where(status: :ocr_complete)
      .in_order
      .map { |p| "--- Page #{p.page_number} ---\n#{p.raw_ocr_text}" }
      .join("\n\n")

    processor = ClaudePostProcessor.new
    entries_data = processor.process(raw_texts, page_count: job.page_count, year_hint: job.year_hint)

    entries_data.each do |entry_data|
      entry = job.journal_entries.create!(
        user: job.user,
        title: entry_data[:title],
        entry_date: entry_data[:date],
        content: entry_data[:text],
        date_detected: entry_data[:date].present?,
        image_indices: entry_data[:image_indices] || []
      )

      attach_images_to_entry(entry, job, entry_data[:image_indices])
    end
  end

  def process_individual_pages(job)
    processor = ClaudePostProcessor.new

    job.job_pages.where(status: :ocr_complete).in_order.each do |page|
      process_single_page(job, page, processor)
    end
  end

  def process_single_page(job, page, processor)
    # Use Claude to generate a title and clean the text
    entries_data = processor.process(
      page.raw_ocr_text,
      page_count: 1,
      year_hint: job.year_hint,
      force_single_entry: true
    )

    entry_data = entries_data.first || {
      title: generate_title_from_text(page.raw_ocr_text),
      text: clean_ocr_text(page.raw_ocr_text),
      date: nil
    }

    entry = job.journal_entries.create!(
      user: job.user,
      title: entry_data[:title],
      entry_date: entry_data[:date],
      content: entry_data[:text],
      date_detected: entry_data[:date].present?,
      image_indices: [page.page_number]
    )

    entry.images.attach(page.image.blob) if page.image.attached?
  end

  def create_entries_from_data(job, entries_data, pages)
    entries_data.each do |entry_data|
      entry = job.journal_entries.create!(
        user: job.user,
        title: entry_data[:title],
        entry_date: entry_data[:date],
        content: entry_data[:text],
        date_detected: entry_data[:date].present?,
        image_indices: entry_data[:image_indices] || pages.pluck(:page_number)
      )

      # Attach images from the pages
      pages.each do |page|
        entry.images.attach(page.image.blob) if page.image.attached?
      end
    end
  end

  def attach_images_to_entry(entry, job, indices)
    # If no indices specified, attach all images
    indices = (1..job.page_count).to_a if indices.blank?

    indices.each do |page_num|
      page = job.job_pages.find_by(page_number: page_num)
      next unless page&.image&.attached?

      entry.images.attach(page.image.blob)
    end
  end

  def generate_title_from_text(text)
    # Simple fallback title generation
    first_line = text.to_s.split("\n").find { |line| line.strip.length > 5 }
    return "Journal Entry" unless first_line

    first_line.strip.truncate(50)
  end

  def clean_ocr_text(text)
    # Remove page markers and clean up whitespace
    text.to_s
      .gsub(/---\s*Page\s*\d+\s*---/, '')
      .strip
      .gsub(/\n{3,}/, "\n\n")
  end

  def send_entry_notifications(job)
    return unless job.user.email_preference == "per_entry"

    job.journal_entries.each do |entry|
      EntriesMailer.entry_transcribed(entry).deliver_later
    end
  end
end
