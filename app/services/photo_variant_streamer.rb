class PhotoVariantStreamer
  EXTENSIONS = {
    "image/jpeg" => "jpg",
    "image/png" => "png",
    "image/gif" => "gif",
    "image/webp" => "webp"
  }.freeze

  VARIANTS = %w[thumbnail small medium large xl original].freeze

  Result = Struct.new(:type, :path, :data, :content_type, :filename, keyword_init: true) do
    def disk?
      type == :disk
    end
  end

  def self.call(photo:, variant:)
    new(photo, variant).call
  end

  def initialize(photo, variant)
    @photo = photo
    @variant = variant
  end

  def call
    return nil unless @photo&.image&.attached?

    build_result(resolved_attachment)
  rescue StandardError => e
    # Never let a variant problem blank out the photo — the original is always
    # a valid image, so fall back to it rather than surfacing a broken tile.
    Rails.logger.warn "PhotoVariantStreamer falling back to original for " \
                      "Photo #{@photo&.id} variant=#{@variant.inspect}: #{e.class}: #{e.message}"
    build_result(@photo.image)
  end

  private

  # Returns something that is guaranteed to have bytes behind it. A variant that
  # background processing has not built yet has a nil key, so asking the storage
  # service for its path blows up; in that case we process it on demand (the same
  # thing Active Storage's own representation endpoint does) and only fall back
  # to the original if that also fails.
  def resolved_attachment
    variant = lookup_variant
    return @photo.image if variant.nil? || variant == @photo.image
    return variant if ready?(variant)

    processed = variant.processed
    ready?(processed) ? processed : @photo.image
  rescue StandardError => e
    Rails.logger.warn "PhotoVariantStreamer could not build variant=#{@variant.inspect} " \
                      "for Photo #{@photo&.id}: #{e.class}: #{e.message}"
    @photo.image
  end

  def ready?(attachment)
    attachment.present? && attachment.key.present?
  rescue StandardError
    false
  end

  def lookup_variant
    case @variant
    when "thumbnail" then @photo.thumbnail
    when "small"     then @photo.small
    when "medium"    then @photo.medium
    when "large"     then @photo.large
    when "xl"        then @photo.xl
    else                  @photo.image
    end
  end

  def build_result(attachment)
    content_type = attachment.content_type
    filename = "#{@photo.title.to_s.parameterize.presence || "photo"}.#{EXTENSIONS.fetch(content_type, "jpg")}"

    if (path = local_path_for(attachment))
      Result.new(type: :disk, path: path, content_type: content_type, filename: filename)
    else
      Result.new(type: :memory, data: attachment.download, content_type: content_type, filename: filename)
    end
  end

  def local_path_for(attachment)
    service = attachment.service
    return nil unless service.is_a?(ActiveStorage::Service::DiskService)
    return nil if attachment.key.blank?

    path = service.path_for(attachment.key)
    File.exist?(path) ? path : nil
  end
end
