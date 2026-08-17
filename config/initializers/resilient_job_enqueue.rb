# Enqueuing a background job must never fail a request whose real work is done.
#
# Photo upload commits the Photo row and its Active Storage blob, and only then
# enqueues follow-up work: our own ImageProcessingJob/ExtractPhotoMetadataJob
# (plain Sidekiq::Job, rescued at their call sites) and Active Storage's own
# AnalyzeJob (ActiveJob). With Redis unreachable that last one raised straight
# out of `save!`, so the user got HTTP 500 for an upload that had actually
# succeeded — and re-uploaded, creating silent duplicates.
#
# Degrading here is safe because none of this work is required for the photo to
# be visible: PhotoVariantStreamer builds variants on demand, and
# BulkImageProcessingJob sweeps up anything left in a pending state.
module ResilientJobEnqueue
  def self.connection_errors
    @connection_errors ||= [
      ("RedisClient::CannotConnectError" if defined?(RedisClient::CannotConnectError)),
      ("RedisClient::ConnectionError" if defined?(RedisClient::ConnectionError)),
      ("Redis::BaseConnectionError" if defined?(Redis::BaseConnectionError))
    ].compact.map(&:constantize) + [ Errno::ECONNREFUSED, SocketError ]
  end
end

ActiveSupport.on_load(:active_job) do
  around_enqueue do |job, block|
    block.call
  rescue *ResilientJobEnqueue.connection_errors => e
    Rails.logger.error(
      "Could not enqueue #{job.class.name}: #{e.class}: #{e.message}. " \
      "Skipped rather than failing the request; recoverable by the background sweep."
    )
    nil
  end
end
