begin
  require "vips"
rescue LoadError
  # libvips absent (CI, lint) - nothing to tune
else
  Vips.concurrency_set(ENV.fetch("VIPS_CONCURRENCY", 1).to_i)
  Vips.cache_set_max(0)
  Vips.cache_set_max_mem(0)
end
