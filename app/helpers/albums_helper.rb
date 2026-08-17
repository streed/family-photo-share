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

    tag.span(class: "privacy-badge privacy-#{album.privacy}",
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

    tag.span(class: "privacy-badge privacy-link",
             title: album.external_password.present? ? "Anyone with the link and password" : "Anyone with the link") do
      concat tag.i("", class: "fas fa-link", "aria-hidden": true)
      concat " Link"
    end
  end
end
