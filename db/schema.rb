# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_07_22_201938) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "album_access_sessions", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.string "session_token", null: false
    t.string "ip_address"
    t.datetime "expires_at", null: false
    t.datetime "accessed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "session_token"], name: "index_album_access_sessions_on_album_id_and_session_token"
    t.index ["album_id"], name: "index_album_access_sessions_on_album_id"
    t.index ["expires_at"], name: "index_album_access_sessions_on_expires_at"
    t.index ["session_token"], name: "index_album_access_sessions_on_session_token", unique: true
  end

  create_table "album_photos", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.bigint "photo_id", null: false
    t.integer "position", default: 0
    t.datetime "added_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "photo_id"], name: "index_album_photos_on_album_id_and_photo_id", unique: true
    t.index ["album_id", "position"], name: "index_album_photos_on_album_id_and_position"
    t.index ["album_id"], name: "index_album_photos_on_album_id"
    t.index ["photo_id"], name: "index_album_photos_on_photo_id"
  end

  create_table "album_view_events", force: :cascade do |t|
    t.bigint "album_id", null: false
    t.string "event_type", null: false
    t.bigint "photo_id"
    t.string "ip_address"
    t.text "user_agent"
    t.string "referrer"
    t.string "session_id"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["album_id", "occurred_at"], name: "index_album_view_events_on_album_id_and_occurred_at"
    t.index ["album_id"], name: "index_album_view_events_on_album_id"
    t.index ["event_type"], name: "index_album_view_events_on_event_type"
    t.index ["occurred_at"], name: "index_album_view_events_on_occurred_at"
    t.index ["photo_id"], name: "index_album_view_events_on_photo_id"
    t.index ["session_id"], name: "index_album_view_events_on_session_id"
  end

  create_table "albums", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.string "privacy", default: "private", null: false
    t.bigint "cover_photo_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.boolean "allow_external_access", default: false, null: false
    t.string "sharing_token"
    t.string "external_password"
    t.index ["allow_external_access"], name: "index_albums_on_allow_external_access"
    t.index ["cover_photo_id"], name: "index_albums_on_cover_photo_id"
    t.index ["created_at"], name: "index_albums_on_created_at"
    t.index ["name"], name: "index_albums_on_name"
    t.index ["privacy", "created_at"], name: "index_albums_on_privacy_and_created_at"
    t.index ["privacy"], name: "index_albums_on_privacy"
    t.index ["sharing_token"], name: "index_albums_on_sharing_token", unique: true
    t.index ["updated_at"], name: "index_albums_on_updated_at"
    t.index ["user_id", "created_at"], name: "index_albums_on_user_id_and_created_at"
    t.index ["user_id", "name"], name: "index_albums_on_user_id_and_name"
    t.index ["user_id"], name: "index_albums_on_user_id"
  end

  create_table "families", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_families_on_created_at"
    t.index ["created_by_id", "created_at"], name: "index_families_on_created_by_id_and_created_at"
    t.index ["created_by_id"], name: "index_families_on_created_by_id"
    t.index ["name"], name: "index_families_on_name"
  end

  create_table "family_invitations", force: :cascade do |t|
    t.bigint "family_id", null: false
    t.bigint "inviter_id", null: false
    t.string "email", null: false
    t.string "token", null: false
    t.string "status", default: "pending", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_family_invitations_on_email"
    t.index ["expires_at"], name: "index_family_invitations_on_expires_at"
    t.index ["family_id", "email"], name: "index_family_invitations_on_family_id_and_email", unique: true
    t.index ["family_id", "status"], name: "index_family_invitations_on_family_id_and_status"
    t.index ["family_id"], name: "index_family_invitations_on_family_id"
    t.index ["inviter_id"], name: "index_family_invitations_on_inviter_id"
    t.index ["status", "created_at"], name: "index_family_invitations_on_status_and_created_at"
    t.index ["token"], name: "index_family_invitations_on_token", unique: true
  end

  create_table "family_memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "family_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "joined_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["family_id", "role"], name: "index_family_memberships_on_family_id_and_role"
    t.index ["family_id"], name: "index_family_memberships_on_family_id"
    t.index ["joined_at"], name: "index_family_memberships_on_joined_at"
    t.index ["user_id"], name: "index_family_memberships_on_user_id", unique: true
  end

  create_table "photos", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "taken_at"
    t.string "location"
    t.string "original_filename"
    t.integer "file_size"
    t.string "content_type"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "processing_completed_at"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "camera_make"
    t.string "camera_model"
    t.index ["created_at"], name: "index_photos_on_created_at"
    t.index ["taken_at"], name: "index_photos_on_taken_at"
    t.index ["user_id", "created_at"], name: "index_photos_on_user_id_and_created_at"
    t.index ["user_id", "taken_at"], name: "index_photos_on_user_id_and_taken_at"
    t.index ["user_id"], name: "index_photos_on_user_id"
  end

  create_table "short_urls", force: :cascade do |t|
    t.string "token", null: false
    t.string "resource_type", null: false
    t.bigint "resource_id", null: false
    t.string "variant"
    t.datetime "expires_at", null: false
    t.datetime "accessed_at"
    t.integer "access_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_short_urls_on_expires_at"
    t.index ["resource_type", "resource_id", "variant"], name: "index_short_urls_on_resource_and_variant"
    t.index ["token"], name: "index_short_urls_on_token", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "display_name"
    t.text "bio"
    t.string "phone_number"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "avatar_url"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "album_access_sessions", "albums"
  add_foreign_key "album_photos", "albums"
  add_foreign_key "album_photos", "photos"
  add_foreign_key "album_view_events", "albums"
  add_foreign_key "album_view_events", "photos"
  add_foreign_key "albums", "photos", column: "cover_photo_id"
  add_foreign_key "albums", "users"
  add_foreign_key "families", "users", column: "created_by_id"
  add_foreign_key "family_invitations", "families"
  add_foreign_key "family_invitations", "users", column: "inviter_id"
  add_foreign_key "family_memberships", "families"
  add_foreign_key "family_memberships", "users"
  add_foreign_key "photos", "users"
end
