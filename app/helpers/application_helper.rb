module ApplicationHelper
  # A top-bar navigation link that marks the section you're currently in.
  def nav_link_to(name, path)
    active = current_page?(path) || request.path.start_with?(path.to_s + "/")

    classes = [
      "rounded-full px-3 py-2 font-semibold no-underline transition-colors",
      active ? "bg-paper-deep text-ink" : "text-body hover:bg-paper-deep hover:text-ink"
    ].join(" ")

    link_to name, path, class: classes, "aria-current": (active ? "page" : nil)
  end

  # Maps a bulk-upload status onto the badge and progress styles defined in
  # app/assets/tailwind/application.css.
  def status_badge_class(status)
    case status
    when "completed" then "badge-family"
    when "processing" then "badge-link"
    when "failed" then "badge-danger"
    when "partial" then "badge-info"
    else "badge-private"
    end
  end

  def progress_bar_class(status)
    case status
    when "completed" then "bg-sage"
    when "failed" then "bg-danger"
    when "partial" then "bg-clay"
    else "bg-bark"
    end
  end

  def qr_code_data_url(text, size: 5)
    require "rqrcode"

    qr = RQRCode::QRCode.new(text)

    # Generate QR code as SVG with styling
    svg = qr.as_svg(
      offset: 0,
      color: "000",
      shape_rendering: "crispEdges",
      module_size: size,
      standalone: true,
      use_path: true,
      viewbox: true
    )

    # Return data URL for embedding
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
