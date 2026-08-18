module AlbumsHelper
  # qr_code_data_url intentionally lives only in ApplicationHelper. A second
  # definition here shadowed it depending on helper load order, silently dropping
  # the viewbox attribute that makes the QR code scale.

  # The single source of truth for how an album's audience is labelled.
  #
  # This was previously hand-rolled in four views with three different class
  # conventions (`badge bg-info`, `privacy-badge privacy-family`, and a dead
  # `public` branch the model no longer allows), so the same album could look
  # different depending on which page you were on.
  def album_privacy_badge(album, detailed: false)
    label =
      case album.privacy
      when "family"
        if detailed && (count = album.family_viewers.size).positive?
          "Family · #{count} #{'person'.pluralize(count)}"
        else
          "Family"
        end
      else
        "Private"
      end

    style = album.privacy == "family" ? "badge-family" : "badge-private"

    tag.span(class: "badge #{style}",
             title: album_privacy_description(album)) do
      concat tag.i("", class: album.privacy == "family" ? "fas fa-users" : "fas fa-lock",
                       "aria-hidden": true)
      concat " "
      concat label
    end
  end

  def album_privacy_description(album)
    if album.privacy == "family"
      "Everyone in your family can see this album"
    else
      "Only you can see this album"
    end
  end

  # A separate marker, because external link sharing is orthogonal to privacy —
  # a Private album can still be shared by link, which nothing in the UI said.
  def album_link_sharing_badge(album)
    return unless album.allow_external_access?

    tag.span(class: "badge badge-link",
             title: album.external_password.present? ? "Anyone with the link and password" : "Anyone with the link") do
      concat tag.i("", class: "fas fa-link", "aria-hidden": true)
      concat " Link"
    end
  end

  # Marks an album the whole family can add to, so it reads as a shared space
  # rather than one person's album that everyone happens to be able to see.
  def album_contributions_badge(album)
    return unless album.allow_contributions? && album.privacy == "family"

    tag.span(class: "badge badge-info",
             title: "Everyone in the family can add their own photos") do
      concat tag.i("", class: "fas fa-user-plus", "aria-hidden": true)
      concat " Family can add"
    end
  end

  # Where a guest appears to be, from their IP.
  #
  # `locations` is the map the controller loaded for the whole page, so this
  # renders 100 rows without 100 lookups. IP geolocation is approximate by
  # nature — the label says so rather than implying a street address.
  def ip_location_label(ip_address, locations = {})
    return content_tag(:span, "Unknown", class: "meta") if ip_address.blank?

    location = locations[ip_address.to_s]

    case location&.status
    when "ok"
      content_tag(:span, location.label.presence || "Unknown", title: "Approximate, from IP #{ip_address}")
    when "private"
      content_tag(:span, "Local network", class: "meta")
    when "failed"
      content_tag(:span, "Unknown", class: "meta", title: "This address couldn't be placed")
    else
      content_tag(:span, "Looking up…", class: "meta", title: "Being resolved in the background")
    end
  end

  # The kind of thing a guest did, as a badge.
  def event_type_badge(event_type)
    style, icon, label =
      case event_type
      when "password_entry"          then [ "badge-family", "fa-unlock", "Opened the album" ]
      when "password_attempt_failed" then [ "badge-danger", "fa-lock", "Wrong password" ]
      when "photo_view"              then [ "badge-info", "fa-eye", "Viewed a photo" ]
      else                                [ "badge-private", "fa-circle", event_type.to_s.humanize ]
      end

    tag.span(class: "badge #{style}") do
      concat tag.i("", class: "fas #{icon}", "aria-hidden": true)
      concat " "
      concat label
    end
  end
end
