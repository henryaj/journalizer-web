require "test_helper"

class UploadToOcrJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "normalize downscales to MAX_DIMENSION and writes a JPEG" do
    skip "libvips not available" unless defined?(Vips::Image)

    Tempfile.create([ "source", ".png" ]) do |source|
      Vips::Image.black(5000, 4000).bandjoin(255).pngsave(source.path)

      Tempfile.create([ "out", ".jpg" ]) do |out|
        UploadToOcrJob.normalize(source.path, out.path)

        result = Vips::Image.new_from_file(out.path)
        assert_equal UploadToOcrJob::MAX_DIMENSION, result.width
        assert_equal 2400, result.height
        assert_equal "jpegload", result.get("vips-loader")
      end
    end
  end

  test "normalize preserves the colours of an RGB image with no alpha" do
    skip "libvips not available" unless defined?(Vips::Image)

    Tempfile.create([ "source", ".png" ]) do |source|
      base = Vips::Image.black(200, 150)
      base.linear(1, 201).bandjoin([ base.linear(1, 100), base.linear(1, 30) ])
        .cast(:uchar).copy(interpretation: :srgb)
        .pngsave(source.path)

      Tempfile.create([ "out", ".jpg" ]) do |out|
        UploadToOcrJob.normalize(source.path, out.path)

        result = Vips::Image.new_from_file(out.path)
        assert_equal 3, result.bands
        assert_in_delta 201, result.getpoint(10, 10)[0], 3
        assert_in_delta 100, result.getpoint(10, 10)[1], 3
        assert_in_delta 30, result.getpoint(10, 10)[2], 3
      end
    end
  end

  test "normalize flattens transparency onto white" do
    skip "libvips not available" unless defined?(Vips::Image)

    Tempfile.create([ "source", ".png" ]) do |source|
      Vips::Image.black(200, 150).bandjoin(0).pngsave(source.path)

      Tempfile.create([ "out", ".jpg" ]) do |out|
        UploadToOcrJob.normalize(source.path, out.path)

        assert_in_delta 255, Vips::Image.new_from_file(out.path).getpoint(10, 10)[0], 2
      end
    end
  end

  test "a page left mid-upload is retryable rather than a silent no-op" do
    job = TranscriptionJob.create!(user: users(:one), status: "uploading",
                                   page_count: 1, user_job_number: 95)
    page = job.job_pages.create!(page_number: 1, status: "uploaded")

    assert page.upload_interrupted?
    assert_includes JobPage.upload_interrupted, page

    page.update!(handwriting_ocr_doc_id: "abc123")
    assert_not page.upload_interrupted?
    assert_not_includes JobPage.upload_interrupted, page
  end

  test "a rate limited upload backs off via retry_on instead of burning the page" do
    skip "libvips not available" unless defined?(Vips::Image)

    job = TranscriptionJob.create!(user: users(:one), status: "uploading",
                                   page_count: 1, user_job_number: 94)
    page = job.job_pages.create!(page_number: 1, status: "pending")
    Tempfile.create([ "page", ".png" ]) do |source|
      Vips::Image.black(80, 60).pngsave(source.path)
      File.open(source.path) do |io|
        page.image.attach(io: io, filename: "page.png", content_type: "image/png")
      end
    end

    rate_limited = Class.new do
      def upload(*, **) = raise HandwritingOcr::RateLimitError, "429 Too Many Requests"
    end

    HandwritingOcr::Client.define_singleton_method(:new) { |*, **| rate_limited.new }
    begin
      assert_enqueued_with(job: UploadToOcrJob, args: [ page.id ]) do
        UploadToOcrJob.perform_now(page.id)
      end
    ensure
      HandwritingOcr::Client.singleton_class.send(:remove_method, :new)
    end

    assert_not page.reload.failed?, "a rate limited page must stay retryable"
  end
end
