module ImageProcessingHelper
  def processing_status_badge(photo)
    return "" unless photo.image.attached?

    if photo.all_variants_ready?
      content_tag :span, "✅ Processed", class: "badge bg-success"
    elsif photo.background_processing_complete?
      content_tag :span, "⚙️ Processing", class: "badge bg-warning"
    else
      content_tag :span, "⏳ Queue", class: "badge bg-secondary"
    end
  end

  def image_with_fallback(photo, size, options = {})
    return "" unless photo.image.attached?

    begin
      variant = photo.best_variant(size)
      image_tag variant, options
    rescue StandardError => e
      Rails.logger.error "Failed to load image variant for Photo #{photo.id}: #{e.message}"

      # Fallback to a placeholder or smaller variant
      placeholder_options = options.merge(
        src: asset_path("placeholder-image.png"),
        alt: "Image loading...",
        class: "#{options[:class]} image-placeholder"
      )

      image_tag placeholder_options[:src], placeholder_options
    end
  end

  def responsive_image_tag(photo, sizes = {}, html_options = {})
    return "" unless photo.image.attached?

    # Default sizes for responsive images
    default_sizes = {
      small: :thumbnail,
      medium: :small,
      large: :medium,
      xl: :large
    }

    sizes = default_sizes.merge(sizes)

    # Generate srcset
    srcset_parts = []
    sizes.each do |breakpoint, variant_size|
      begin
        variant = photo.best_variant(variant_size)
        width = ImageProcessingService::THUMBNAIL_SIZES[variant_size][:width]
        srcset_parts << "#{url_for(variant)} #{width}w"
      rescue StandardError => e
        Rails.logger.error "Failed to generate srcset for Photo #{photo.id}, size #{variant_size}: #{e.message}"
      end
    end

    # Use the largest available variant as src
    src_variant = photo.best_variant(sizes.values.last)

    html_options = html_options.merge(
      srcset: srcset_parts.join(", "),
      sizes: "(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
    ) if srcset_parts.any?

    image_tag src_variant, html_options
  rescue StandardError => e
    Rails.logger.error "Failed to generate responsive image for Photo #{photo.id}: #{e.message}"
    content_tag :div, "Image loading...", class: "image-placeholder #{html_options[:class]}"
  end
end
