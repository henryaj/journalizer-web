require "zip"

class ExportsController < ApplicationController
  before_action :require_authentication

  def create
    entries = Current.user.journal_entries.not_expired.recent

    if entries.empty?
      redirect_to dashboard_path, alert: "No entries to export."
      return
    end

    zip_data = generate_zip(entries)
    timestamp = Time.current.strftime("%Y%m%d-%H%M%S")

    send_data zip_data,
      filename: "journalizer-export-#{timestamp}.zip",
      type: "application/zip",
      disposition: "attachment"
  end

  private

  def generate_zip(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |entry|
        # Add markdown file
        filename = if entry.entry_date
          "#{entry.entry_date.iso8601}-#{entry.id}.md"
        else
          "#{entry.id}.md"
        end
        zip.put_next_entry(filename)
        zip.write(entry.to_markdown)

        # Add images
        entry.images.each_with_index do |image, index|
          date_prefix = entry.entry_date&.iso8601 || entry.created_at.strftime("%Y%m%d%H%M%S")
          image_filename = "images/journal-#{date_prefix}-#{index.to_s.rjust(3, '0')}.jpg"
          zip.put_next_entry(image_filename)
          zip.write(image.download)
        end
      end
    end.string
  end
end
