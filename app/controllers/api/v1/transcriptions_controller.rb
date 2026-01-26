module Api
  module V1
    class TranscriptionsController < BaseController
      # POST /api/v1/transcriptions
      # Accept base64 images via API
      def create
        images = params[:images]
        return render_error("No images provided") if images.blank?

        page_count = images.length

        unless current_user.has_credits?(page_count)
          return render_error("Insufficient credits. You have #{current_user.credit_balance} credits but need #{page_count}.", status: :payment_required)
        end

        job = current_user.transcription_jobs.create!(
          page_count: page_count,
          status: :pending,
          year_hint: params[:year].presence&.to_i
        )

        # Decode and attach images
        images.each_with_index do |img_data, index|
          job_page = job.job_pages.create!(page_number: index)

          # Handle data URL or raw base64
          img_data = img_data.split(",").last if img_data.include?(",")
          decoded = Base64.decode64(img_data)

          job_page.image.attach(
            io: StringIO.new(decoded),
            filename: "page_#{index}.jpg",
            content_type: "image/jpeg"
          )
        end

        # Deduct credits and enqueue job
        current_user.deduct_credits!(page_count, job: job)
        OcrPipelineJob.perform_later(job.id)

        render json: {
          job_id: job.id,
          status: job.status,
          page_count: page_count,
          status_url: api_v1_transcription_url(job)
        }, status: :accepted
      end

      # GET /api/v1/transcriptions/:id
      def show
        job = current_user.transcription_jobs.find(params[:id])

        render json: {
          id: job.id,
          status: job.status,
          page_count: job.page_count,
          error: job.error_message,
          entries: job.journal_entries.map { |e| { id: e.id, date: e.entry_date.iso8601 } },
          created_at: job.created_at.iso8601,
          started_at: job.started_at&.iso8601,
          completed_at: job.completed_at&.iso8601
        }
      end
    end
  end
end
