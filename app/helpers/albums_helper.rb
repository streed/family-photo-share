module AlbumsHelper
  def qr_code_data_url(url)
    require "rqrcode"

    qrcode = RQRCode::QRCode.new(url)

    # Generate SVG string
    svg = qrcode.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )

    # Convert to data URL
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
