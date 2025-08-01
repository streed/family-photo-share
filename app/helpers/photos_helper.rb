module PhotosHelper
  def photo_url(photo, variant = :medium)
    return nil unless photo&.image&.attached?

    case variant
    when :thumbnail
      photo.thumbnail
    when :medium
      photo.medium
    when :large
      photo.large
    else
      photo.image
    end
  end

  def photo_tag(photo, variant = :medium, **options)
    return content_tag(:div, "No image", class: "no-image") unless photo&.image&.attached?

    options[:alt] ||= photo.title
    options[:class] = [ options[:class], "photo-image", "photo-#{variant}" ].compact.join(" ")

    if photo.image_processed?
      image_tag(photo_url(photo, variant), options)
    else
      content_tag(:div, "Processing...", class: "photo-processing")
    end
  end

  def formatted_photo_date(photo)
    date = photo.taken_at || photo.created_at
    date.strftime("%B %d, %Y at %I:%M %p")
  end

  def photo_title_or_default(photo)
    photo.title.presence || "Untitled Photo"
  end

  def truncated_photo_title(photo, length: 30)
    truncate(photo_title_or_default(photo), length: length)
  end

  def robust_photo_url(photo, variant = :xl)
    return nil unless photo&.image&.attached?

    # Always return original if processing isn't complete
    unless photo.background_processing_complete?
      return photo.short_original_url
    end

    # Return the requested variant URL
    case variant.to_sym
    when :thumbnail
      photo.short_thumbnail_url
    when :small
      photo.short_small_url
    when :medium
      photo.short_medium_url
    when :large
      photo.short_large_url
    when :xl
      photo.short_xl_url
    when :original
      photo.short_original_url
    else
      photo.short_original_url
    end
  rescue => e
    Rails.logger.warn "Error getting photo URL for variant #{variant}: #{e.message}"
    # Fallback to original
    photo.short_original_url
  end
end
