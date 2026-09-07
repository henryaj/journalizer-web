require "test_helper"

class ActiveStorageVariantsTest < ActiveSupport::TestCase
  # image_processing only asks libvips to shrink while decoding when the loader
  # options are empty and the first operation is a resize. Miss either and a
  # 24MP phone photo gets decoded at full resolution first, which costs ~270MB
  # of RSS per thumbnail and OOM-kills a 1GB container.
  test "variants shrink on load instead of decoding the source at full resolution" do
    skip "libvips not available" unless defined?(Vips::Image)

    captured = capture_processor_call do
      Tempfile.create([ "source", ".png" ]) do |source|
        Vips::Image.black(600, 400).pngsave(source.path)

        File.open(source.path) do |file|
          ActiveStorage.variant_transformer
            .new(resize_to_limit: [ 400, 400 ])
            .send(:process, file, format: :png)
        end
      end
    end

    assert_empty captured[:loader], "loader options defeat vips shrink-on-load"
    assert_equal "resize_to_limit", captured[:operations].dig(0, 0).to_s
  end

  test "a variant is still a correctly sized image of the requested format" do
    skip "libvips not available" unless defined?(Vips::Image)

    Tempfile.create([ "source", ".png" ]) do |source|
      Vips::Image.black(5712, 4284).pngsave(source.path)

      blob = File.open(source.path) do |io|
        ActiveStorage::Blob.create_and_upload!(
          io: io, filename: "page.png", content_type: "image/png"
        )
      end

      blob.variant(resize_to_limit: [ 400, 400 ]).processed.image.blob.open do |file|
        image = Vips::Image.new_from_file(file.path)
        assert_equal "pngload", image.get("vips-loader")
        assert_equal 400, image.width
        assert_equal 300, image.height
      end
    end
  end

  private
    def capture_processor_call
      captured = nil
      processor = ImageProcessing::Vips::Processor
      processor.define_singleton_method(:call) do |**kwargs|
        captured = kwargs
        nil
      end
      yield
      captured
    ensure
      processor.singleton_class.send(:remove_method, :call)
    end
end
