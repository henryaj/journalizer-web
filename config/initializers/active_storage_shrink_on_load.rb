# ActiveStorage's transformer hard-codes `.loader(page: 0)`, and image_processing
# only lets libvips shrink while decoding when the loader options are empty. So
# every variant decoded its source at full resolution first: a 5712x4284 iPhone
# HEIC cost ~275MB of RSS instead of ~8MB, and a review page's worth of them in
# flight at once OOM-killed Puma inside its 1GB container.
#
# Dropping `page: 0` costs nothing here - libvips already reads the first page of
# a multi-page source by default.
ActiveStorage::Transformers::Vips.class_eval do
  private
    def process(file, format:)
      processor.source(file).convert(format).apply(operations).call
    end
end
