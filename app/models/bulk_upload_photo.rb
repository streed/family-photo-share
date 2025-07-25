class BulkUploadPhoto < ApplicationRecord
  belongs_to :bulk_upload
  belongs_to :photo
end