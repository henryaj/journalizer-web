module Api
  module V1
    class EntriesController < BaseController
      before_action :set_entry, only: [:show, :markdown, :image, :mark_synced]

      # GET /api/v1/entries
      # Params: since (ISO date), limit (default 50), unsynced_only (boolean)
      def index
        entries = current_user.journal_entries.not_expired.recent

        if params[:since].present?
          since = Date.parse(params[:since])
          entries = entries.where("created_at >= ?", since.beginning_of_day)
        end

        entries = entries.unsynced if params[:unsynced_only] == "true"
        entries = entries.limit(params[:limit] || 50)

        render json: {
          entries: entries.map { |e| serialize_entry(e) },
          meta: {
            total: entries.count,
            fetched_at: Time.current.iso8601
          }
        }
      end

      # GET /api/v1/entries/:id
      def show
        render json: { entry: serialize_entry(@entry, include_images: true) }
      end

      # GET /api/v1/entries/:id/markdown
      def markdown
        render plain: @entry.to_markdown, content_type: "text/markdown"
      end

      # GET /api/v1/entries/:id/images/:index
      def image
        attachment = @entry.images[params[:index].to_i]
        raise ActiveRecord::RecordNotFound unless attachment

        redirect_to rails_blob_url(attachment, disposition: "inline"), allow_other_host: true
      end

      # POST /api/v1/entries/:id/mark_synced
      def mark_synced
        @entry.mark_synced!
        render json: { success: true }
      end

      private

      def set_entry
        @entry = current_user.journal_entries.find(params[:id])
      end

      def serialize_entry(entry, include_images: false)
        data = {
          id: entry.id,
          entry_date: entry.entry_date&.iso8601,
          content: entry.content,
          date_detected: entry.date_detected,
          source: entry.source,
          synced: entry.synced,
          created_at: entry.created_at.iso8601,
          expires_at: entry.expires_at&.iso8601,
          image_count: entry.images.count
        }

        if include_images && entry.images.any?
          data[:image_urls] = entry.images.map.with_index do |_img, i|
            api_v1_entry_image_url(entry, i)
          end
        end

        data
      end
    end
  end
end
