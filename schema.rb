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

ActiveRecord::Schema[8.1].define(version: 2026_03_21_151101) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accesses", id: :serial, force: :cascade do |t|
    t.integer "access_type_id", null: false
    t.datetime "created_at", null: false
    t.integer "talk_type_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "acquired_groups", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "acquired_packages", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id"
    t.integer "package_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "acquired_resources", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id"
    t.integer "resource_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "activations", id: :serial, force: :cascade do |t|
    t.boolean "agreement", default: false
    t.string "token", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "allowed_extensions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "extension_id", null: false
    t.bigint "format_id", null: false
    t.datetime "updated_at", null: false
    t.index ["extension_id"], name: "index_allowed_extensions_on_extension_id"
    t.index ["format_id"], name: "index_allowed_extensions_on_format_id"
  end

  create_table "allowed_file_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "format_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["format_id"], name: "index_allowed_file_types_on_format_id"
  end

  create_table "assignments", id: :serial, force: :cascade do |t|
    t.integer "centre_id"
    t.datetime "created_at", null: false
    t.integer "role_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "attached_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.bigint "happening_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id"], name: "index_attached_groups_on_group_id"
    t.index ["user_id"], name: "index_attached_groups_on_user_id"
  end

  create_table "aws_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "aws_endpoints", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "banned_passwords", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "buckets", id: :serial, force: :cascade do |t|
    t.integer "aws_account_endpoint_id"
    t.integer "aws_subdomain_endpoint_id"
    t.datetime "created_at", null: false
    t.string "credential_prefix"
    t.string "name"
    t.integer "region_id"
    t.datetime "updated_at", null: false
  end

  create_table "bundle_items", force: :cascade do |t|
    t.integer "bundle_id"
    t.bigint "bundleable_id"
    t.string "bundleable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bundleable_type", "bundleable_id"], name: "index_bundle_items_on_bundleable_type_and_bundleable_id"
  end

  create_table "bundles", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "cumulative_penny_price", default: 0, null: false
    t.bigint "happening_id"
    t.integer "man_penny_price", default: 0, null: false
    t.string "name"
    t.integer "penny_price", default: 0, null: false
    t.integer "price_version", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "centre_formats", id: :serial, force: :cascade do |t|
    t.integer "centre_id", null: false
    t.datetime "created_at", null: false
    t.boolean "current", default: true, null: false
    t.integer "format_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "centres", id: :serial, force: :cascade do |t|
    t.integer "bucket_id", null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 80, null: false
    t.text "notes"
    t.string "sales_email", default: "", null: false
    t.datetime "updated_at", null: false
  end

  create_table "contributions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "main", default: true, null: false
    t.integer "recording_id", null: false
    t.integer "speaker_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "countries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "courses", id: :serial, force: :cascade do |t|
    t.integer "centre_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "group", default: ""
    t.text "notes"
    t.boolean "protected", default: false
    t.integer "sales_scope_id", null: false
    t.boolean "sets", default: false
    t.date "start_date", null: false
    t.string "sub_title"
    t.integer "talk_type_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "default_bundles", force: :cascade do |t|
    t.integer "course_id", null: false
    t.datetime "created_at", null: false
    t.integer "man_penny_price", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  create_table "default_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "defaultable_id"
    t.string "defaultable_type"
    t.bigint "format_id"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["defaultable_type", "defaultable_id"], name: "index_default_items_on_defaultable_type_and_defaultable_id"
    t.index ["format_id"], name: "index_default_items_on_format_id"
  end

  create_table "extensions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "family_digests", force: :cascade do |t|
    t.boolean "complete", default: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.date "published_on"
    t.datetime "updated_at", null: false
  end

  create_table "formats", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "downloadable", default: false
    t.string "name", limit: 24, null: false
    t.boolean "packageable", default: false
    t.boolean "purchasable", default: false
    t.datetime "updated_at", null: false
  end

  create_table "group_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "group_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "happening_searches", force: :cascade do |t|
    t.boolean "centre"
    t.integer "centre_id"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "happening_id"
    t.integer "happening_ids", array: true
    t.integer "page"
    t.integer "speaker_id"
    t.date "start_date"
    t.string "text_search"
    t.datetime "updated_at", null: false
  end

  create_table "happenings", id: :serial, force: :cascade do |t|
    t.string "course_visit", limit: 3, default: ""
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "happenable_id"
    t.string "happenable_type"
    t.boolean "protected", default: false
    t.integer "sales_scope_id"
    t.text "searchable_text"
    t.date "start_date", null: false
    t.integer "talk_type_id"
    t.string "title", limit: 255, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "venue_id", null: false
    t.index "to_tsvector('english'::regconfig, searchable_text)", name: "index_happenings_on_searchable_text_tsvector", using: :gin
  end

  create_table "key_holders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.bigint "role_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_key_holders_on_model_id"
    t.index ["role_id"], name: "index_key_holders_on_role_id"
  end

  create_table "lockers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.bigint "role_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_lockers_on_model_id"
    t.index ["role_id"], name: "index_lockers_on_role_id"
  end

  create_table "locks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "lockable_id"
    t.string "lockable_type"
    t.datetime "updated_at", null: false
    t.index ["lockable_type", "lockable_id"], name: "index_locks_on_lockable_type_and_lockable_id"
  end

  create_table "mbr_types", force: :cascade do |t|
    t.string "name"
  end

  create_table "memberships", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "joinable_id"
    t.string "joinable_type"
    t.integer "mbr_type_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["joinable_type", "joinable_id"], name: "index_memberships_on_joinable_type_and_joinable_id"
  end

  create_table "models", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "notices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "happening_id", null: false
    t.boolean "published", default: false
    t.datetime "published_at"
    t.datetime "updated_at", null: false
    t.index ["happening_id"], name: "index_notices_on_happening_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "order_id"
    t.bigint "orderable_id"
    t.string "orderable_type"
    t.integer "penny_price"
    t.datetime "updated_at", null: false
    t.index ["orderable_type", "orderable_id"], name: "index_order_items_on_orderable_type_and_orderable_id"
  end

  create_table "order_searches", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "order_id"
    t.date "start_date"
    t.string "text_search"
    t.datetime "updated_at", null: false
    t.integer "user_id"
  end

  create_table "orders", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "happening_id"
    t.integer "penny_price"
    t.string "reason", default: ""
    t.string "type"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "packages", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "format_id", null: false
    t.integer "happening_id", null: false
    t.boolean "purchasable", default: false
    t.datetime "updated_at", null: false
  end

  create_table "parentships", id: :serial, force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.integer "parent_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "portraits", id: :serial, force: :cascade do |t|
    t.string "avatar"
    t.datetime "created_at", null: false
    t.integer "crop_h", default: 200
    t.integer "crop_w", default: 200
    t.integer "crop_x", default: 100
    t.integer "crop_y", default: 100
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "presentations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "main", default: true, null: false
    t.integer "speaker_id", null: false
    t.integer "transcript_id", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "man_penny_price", default: 0, null: false
    t.integer "penny_price", default: 0, null: false
    t.integer "resource_id", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "protected_admins", force: :cascade do |t|
    t.bigint "administerable_id", null: false
    t.string "administerable_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["administerable_type", "administerable_id"], name: "index_protected_admins_on_administerable"
    t.index ["user_id"], name: "index_protected_admins_on_user_id"
  end

  create_table "recipientships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "family_digest_id", null: false
    t.boolean "sent", default: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
  end

  create_table "recording_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "recordings", id: :serial, force: :cascade do |t|
    t.text "content", default: "", null: false
    t.datetime "created_at", null: false
    t.integer "duration", default: 0, null: false
    t.integer "file_length"
    t.integer "happening_id", null: false
    t.integer "number", null: false
    t.integer "priority"
    t.text "searchable_text"
    t.datetime "start_datetime", null: false
    t.string "title", limit: 255, null: false
    t.datetime "transcribed_at"
    t.integer "transcription_status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "uploaded", default: false, null: false
    t.index "to_tsvector('english'::regconfig, searchable_text)", name: "index_recordings_on_searchable_text_tsvector", using: :gin
    t.index ["transcription_status", "priority"], name: "index_recordings_on_transcription_status_and_priority"
  end

  create_table "regions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "registrations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "happening_id", null: false
    t.bigint "membership_id", null: false
    t.datetime "updated_at", null: false
    t.index ["happening_id"], name: "index_registrations_on_happening_id"
    t.index ["membership_id"], name: "index_registrations_on_membership_id"
  end

  create_table "reports", force: :cascade do |t|
    t.text "body"
    t.boolean "closed", default: false
    t.datetime "created_at", null: false
    t.bigint "reportable_id", null: false
    t.string "reportable_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["reportable_type", "reportable_id"], name: ":reportable_index"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "resource_searches", force: :cascade do |t|
    t.boolean "centre"
    t.integer "centre_id"
    t.datetime "created_at", null: false
    t.date "digest_date"
    t.date "end_date"
    t.integer "happening_id"
    t.integer "happening_ids", array: true
    t.string "happening_type"
    t.integer "page"
    t.integer "priority"
    t.integer "resource_id"
    t.integer "speaker_id"
    t.date "start_date"
    t.string "text_search"
    t.integer "transcription_status"
    t.datetime "updated_at", null: false
  end

  create_table "resources", id: :serial, force: :cascade do |t|
    t.integer "bucket_id"
    t.datetime "created_at", null: false
    t.integer "format_id", null: false
    t.boolean "processed", default: false
    t.boolean "purchasable", default: false
    t.integer "recording_id", null: false
    t.integer "talk_type_id", default: 4, null: false
    t.datetime "updated_at", null: false
    t.boolean "uploaded", default: false
    t.string "vimeo_url"
    t.index ["format_id", "recording_id"], name: "index_resources_on_format_id_and_recording_id", unique: true
  end

  create_table "responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["report_id"], name: "index_responses_on_report_id"
    t.index ["user_id"], name: "index_responses_on_user_id"
  end

  create_table "roles", id: :serial, force: :cascade do |t|
    t.boolean "centre_role", default: true, null: false
    t.datetime "created_at"
    t.string "name", limit: 40, null: false
    t.datetime "updated_at"
  end

  create_table "sales_scopes", id: :serial, force: :cascade do |t|
    t.boolean "affiliates", default: true
    t.boolean "members", default: true
    t.string "name", null: false
  end

  create_table "solid_queue_tables", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "speakers", id: :serial, force: :cascade do |t|
    t.string "avatar"
    t.datetime "created_at", null: false
    t.integer "crop_h", default: 250
    t.integer "crop_w", default: 250
    t.integer "crop_x", default: 100
    t.integer "crop_y", default: 100
    t.integer "deg", default: 0
    t.string "forename", default: ""
    t.text "notes", default: ""
    t.string "stage_name", default: ""
    t.string "surname", default: ""
    t.string "title", default: ""
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.decimal "zoom", precision: 10, scale: 9, default: "1.0"
  end

  create_table "statuses", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "talk_types", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 40
    t.datetime "updated_at", null: false
  end

  create_table "transcription_chunks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "duration"
    t.string "file_path"
    t.string "original_filename"
    t.float "start_time"
    t.integer "status"
    t.bigint "transcription_job_id", null: false
    t.datetime "updated_at", null: false
    t.index ["transcription_job_id"], name: "index_transcription_chunks_on_transcription_job_id"
  end

  create_table "transcription_jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "ended_at"
    t.text "error_message"
    t.bigint "recording_id", null: false
    t.decimal "speed", precision: 4, scale: 1, default: "0.0"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_transcription_jobs_on_recording_id"
    t.index ["status"], name: "index_transcription_jobs_on_status"
  end

  create_table "transcription_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "message"
    t.bigint "recording_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_transcription_logs_on_recording_id"
  end

  create_table "user_searches", id: :serial, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.datetime "updated_at", null: false
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "archive_reason"
    t.boolean "archived", default: false
    t.integer "centre_id"
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.inet "current_sign_in_ip"
    t.date "d_o_b"
    t.string "email", null: false
    t.string "encrypted_password"
    t.integer "failed_attempts", default: 0, null: false
    t.boolean "family_mailings", default: false, null: false
    t.string "forename", null: false
    t.date "init_agree"
    t.datetime "last_activity"
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.datetime "locked_at"
    t.integer "photo_id"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count"
    t.boolean "speaker", default: false, null: false
    t.integer "sponsor_id"
    t.text "sponsor_notes"
    t.string "surname", null: false
    t.integer "talk_type_id"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.boolean "user_agreed", default: false, null: false
  end

  create_table "users4_notification_searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "hours_ago"
    t.datetime "updated_at", null: false
  end

  create_table "venues", id: :serial, force: :cascade do |t|
    t.integer "country_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.string "name", limit: 80, null: false
    t.text "notes"
    t.datetime "updated_at", null: false
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "allowed_extensions", "extensions"
  add_foreign_key "allowed_extensions", "formats"
  add_foreign_key "allowed_file_types", "formats"
  add_foreign_key "attached_groups", "groups"
  add_foreign_key "attached_groups", "users"
  add_foreign_key "default_items", "formats"
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "key_holders", "models"
  add_foreign_key "key_holders", "roles"
  add_foreign_key "lockers", "models"
  add_foreign_key "lockers", "roles"
  add_foreign_key "notices", "happenings"
  add_foreign_key "protected_admins", "users"
  add_foreign_key "registrations", "happenings"
  add_foreign_key "registrations", "memberships"
  add_foreign_key "reports", "users"
  add_foreign_key "responses", "reports"
  add_foreign_key "responses", "users"
  add_foreign_key "transcription_chunks", "transcription_jobs"
  add_foreign_key "transcription_jobs", "recordings"
  add_foreign_key "transcription_logs", "recordings"
end
