# Configure image processing
if Rails.env.development? || Rails.env.test?
  # Use mini_magick in development and test
  Rails.application.config.active_storage.variant_processor = :mini_magick
end

# Set up image analysis
Rails.application.config.active_storage.analyze_images = true

# Configure image quality and optimization
Rails.application.config.active_storage.variant_processor = :mini_magick