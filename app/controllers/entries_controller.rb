class EntriesController < ApplicationController
  before_action :require_authentication

  def download
    entry = Current.user.journal_entries.not_expired.find(params[:id])

    filename = if entry.entry_date
      "journal-#{entry.entry_date.iso8601}.md"
    else
      "journal-#{entry.id}.md"
    end

    send_data entry.to_markdown,
      filename: filename,
      type: "text/markdown",
      disposition: "attachment"
  end

  def destroy
    entry = Current.user.journal_entries.find(params[:id])
    entry.destroy
    redirect_to dashboard_path, notice: "Entry deleted."
  end
end
