module HandwritingOcr
  class Error < StandardError; end
  class RateLimitError < Error; end
  class UploadError < Error; end
  class TimeoutError < Error; end
end
