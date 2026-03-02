module HandwritingOcr
  class Client
    BASE_URL = "https://www.handwritingocr.com/api/v3/documents".freeze

    def initialize(api_key: nil)
      @api_key = api_key || ENV.fetch("HANDWRITING_OCR_API_KEY")
    end

    # Upload an image and return the document ID
    def upload(image_data, filename: "page.jpg", content_type: "image/jpeg")
      response = connection.post do |req|
        req.headers["Authorization"] = "Bearer #{@api_key}"
        req.headers["Content-Type"] = "multipart/form-data"
        req.body = {
          file: Faraday::Multipart::FilePart.new(
            StringIO.new(image_data),
            content_type,
            filename
          ),
          action: "transcribe"
        }
      end

      handle_upload_response(response)
    end

    # Poll for result - returns { status: :completed/:processing/:failed, text: "...", error: "..." }
    def get_result(doc_id)
      result_url = "#{BASE_URL}/#{doc_id}.txt"

      response = Faraday.get(result_url) do |req|
        req.headers["Authorization"] = "Bearer #{@api_key}"
      end

      case response.status
      when 200
        { status: :completed, text: response.body }
      when 202
        { status: :processing }
      when 429
        raise RateLimitError, "Rate limited"
      else
        { status: :failed, error: "HTTP #{response.status}: #{response.body}" }
      end
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.request :multipart
        f.request :url_encoded
        f.adapter Faraday.default_adapter
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end

    def handle_upload_response(response)
      case response.status
      when 201
        data = JSON.parse(response.body)
        data["id"]
      when 429
        raise RateLimitError, "Rate limited - please wait before retrying"
      else
        raise UploadError, "Upload failed (HTTP #{response.status}): #{response.body}"
      end
    end
  end
end
