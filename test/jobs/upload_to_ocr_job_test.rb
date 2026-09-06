require "test_helper"

class UploadToOcrJobTest < ActiveSupport::TestCase
  test "normalize downscales to MAX_DIMENSION and writes a JPEG" do
    skip "libvips not available" unless defined?(Vips)

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
    skip "libvips not available" unless defined?(Vips)

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
    skip "libvips not available" unless defined?(Vips)

    Tempfile.create([ "source", ".png" ]) do |source|
      Vips::Image.black(200, 150).bandjoin(0).pngsave(source.path)

      Tempfile.create([ "out", ".jpg" ]) do |out|
        UploadToOcrJob.normalize(source.path, out.path)

        assert_in_delta 255, Vips::Image.new_from_file(out.path).getpoint(10, 10)[0], 2
      end
    end
  end
end
