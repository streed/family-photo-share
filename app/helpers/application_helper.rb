module ApplicationHelper
  def qr_code_data_url(text, size: 5)
    require 'rqrcode'
    
    qr = RQRCode::QRCode.new(text)
    
    # Generate QR code as SVG with styling
    svg = qr.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: size,
      standalone: true,
      use_path: true,
      viewbox: true
    )
    
    # Return data URL for embedding
    "data:image/svg+xml;base64,#{Base64.strict_encode64(svg)}"
  end
end
