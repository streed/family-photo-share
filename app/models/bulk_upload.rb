class BulkUpload < ApplicationRecord
  belongs_to :user
  belongs_to :album, optional: true

  has_many :bulk_upload_photos, dependent: :destroy
  has_many :photos, through: :bulk_upload_photos

  has_many_attached :images

  # Status constants
  STATUSES = {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    partial: "partial"
  }.freeze

  validates :status, inclusion: { in: STATUSES.values }

  def pending?
    status == STATUSES[:pending]
  end

  def processing?
    status == STATUSES[:processing]
  end

  def completed?
    status == STATUSES[:completed]
  end

  def failed?
    status == STATUSES[:failed]
  end

  def partial?
    status == STATUSES[:partial]
  end

  def success_rate
    return 0 if total_count == 0
    ((processed_count - failed_count).to_f / total_count * 100).round(1)
  end

  def add_error(filename, error_message)
    self.error_messages ||= ""
    self.error_messages += "#{filename}: #{error_message}\n"
    save
  end
end
