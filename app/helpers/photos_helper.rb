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

  # Renders a photo thumbnail that degrades visibly instead of silently.
  #
  # Grids used to emit a bare image_tag, so any failure to fetch the image left
  # an empty tile and the viewer could not tell whether the photo was missing,
  # still processing, or never added to the album. This lazy-loads, and on error
  # swaps in a labelled placeholder rather than a blank square.
  def photo_thumbnail_tag(photo, variant: :thumbnail, css_class: "photo-thumbnail", **options)
    return photo_unavailable_tag("Image missing") unless photo&.image&.attached?

    fallback = "this.onerror=null;this.classList.add('photo-thumbnail-failed');" \
               "this.alt='Image unavailable';"

    image_tag robust_photo_url(photo, variant),
              **options.reverse_merge(
                alt: photo_title_or_default(photo),
                class: css_class,
                loading: "lazy",
                decoding: "async",
                onerror: fallback
              )
  end

  def photo_unavailable_tag(message)
    content_tag(:div, class: "photo-unavailable") do
      concat content_tag(:i, "", class: "fas fa-image", "aria-hidden": true)
      concat content_tag(:span, message)
    end
  end

  # A small corner badge telling the viewer whether a photo is still being
  # processed or has failed outright. Both used to look identical (and permanent).
  def photo_processing_badge(photo)
    return if photo.processing_ready?

    if photo.processing_failed?
      content_tag(:span, class: "photo-state-badge photo-state-badge-failed",
                         title: "Optimized versions couldn't be generated") do
        concat content_tag(:i, "", class: "fas fa-triangle-exclamation", "aria-hidden": true)
        concat content_tag(:span, "Needs attention", class: "photo-state-badge-text")
      end
    else
      content_tag(:span, class: "photo-state-badge photo-state-badge-pending",
                         title: "Still generating optimized versions") do
        concat content_tag(:i, "", class: "fas fa-cog fa-spin", "aria-hidden": true)
        concat content_tag(:span, "Processing", class: "photo-state-badge-text")
      end
    end
  end

  def truncated_photo_title(photo, length: 30)
    truncate(photo_title_or_default(photo), length: length)
  end

  # URL for a photo at the requested size.
  #
  # This used to return the ORIGINAL whenever background processing hadn't
  # finished, which meant a grid of unprocessed photos downloaded full-size
  # images as thumbnails — and, because `all_variants_ready?` was permanently
  # false, that was effectively every photo. PhotoVariantStreamer now builds a
  # missing variant on demand and falls back to the original itself, so asking
  # for the real size is both correct and dramatically smaller.
  def robust_photo_url(photo, variant = :xl)
    return nil unless photo&.image&.attached?

    case variant.to_sym
    when :thumbnail then photo.short_thumbnail_url
    when :small     then photo.short_small_url
    when :medium    then photo.short_medium_url
    when :large     then photo.short_large_url
    when :xl        then photo.short_xl_url
    else                 photo.short_original_url
    end
  rescue => e
    Rails.logger.warn "Error getting photo URL for variant #{variant}: #{e.message}"
    photo.short_original_url
  end
end
