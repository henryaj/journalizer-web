class EntriesController < ApplicationController
  before_action :require_authentication

  def index
    @pagy, @entries = pagy(Current.user.journal_entries.not_expired.order(entry_date: :desc, created_at: :desc))
  end

  def download
    entry = Current.user.journal_entries.not_expired.find(params[:id])
    date_part = entry.entry_date&.iso8601 || entry.id

    case params[:format]
    when "pdf"
      pdf_data = PdfGenerator.new(entry).generate
      send_data pdf_data,
        filename: "journal-#{date_part}.pdf",
        type: "application/pdf",
        disposition: "attachment"
    else
      send_data entry.to_markdown,
        filename: "journal-#{date_part}.md",
        type: "text/markdown",
        disposition: "attachment"
    end
  end

  def destroy
    entry = Current.user.journal_entries.find(params[:id])
    entry.destroy
    redirect_to dashboard_path, notice: "Entry deleted."
  end
end
