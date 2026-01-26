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

ActiveRecord::Schema[8.1].define(version: 2026_01_26_121932) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.string "checksum"
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

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "name", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.string "token_prefix", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id", "revoked_at"], name: "index_api_tokens_on_user_id_and_revoked_at"
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "job_pages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "handwriting_ocr_doc_id"
    t.integer "orientation"
    t.bigint "page_group_id"
    t.integer "page_number", null: false
    t.text "raw_ocr_text"
    t.string "status", default: "pending", null: false
    t.bigint "transcription_job_id", null: false
    t.datetime "updated_at", null: false
    t.index ["handwriting_ocr_doc_id"], name: "index_job_pages_on_handwriting_ocr_doc_id"
    t.index ["page_group_id"], name: "index_job_pages_on_page_group_id"
    t.index ["transcription_job_id", "page_number"], name: "index_job_pages_on_transcription_job_id_and_page_number", unique: true
    t.index ["transcription_job_id"], name: "index_job_pages_on_transcription_job_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.boolean "date_detected", default: false
    t.date "entry_date"
    t.datetime "expires_at"
    t.jsonb "image_indices", default: []
    t.string "source", default: "handwritten-ocr"
    t.boolean "synced", default: false
    t.string "title"
    t.bigint "transcription_job_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["expires_at"], name: "index_journal_entries_on_expires_at"
    t.index ["transcription_job_id"], name: "index_journal_entries_on_transcription_job_id"
    t.index ["user_id", "entry_date"], name: "index_journal_entries_on_user_id_and_entry_date"
    t.index ["user_id", "synced"], name: "index_journal_entries_on_user_id_and_synced"
    t.index ["user_id"], name: "index_journal_entries_on_user_id"
  end

  create_table "page_credits", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "balance_after", null: false
    t.datetime "created_at", null: false
    t.string "stripe_payment_intent_id"
    t.string "transaction_type", null: false
    t.bigint "transcription_job_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["stripe_payment_intent_id"], name: "index_page_credits_on_stripe_payment_intent_id", unique: true
    t.index ["transcription_job_id"], name: "index_page_credits_on_transcription_job_id"
    t.index ["user_id", "created_at"], name: "index_page_credits_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_page_credits_on_user_id"
  end

  create_table "page_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "group_number", null: false
    t.bigint "transcription_job_id", null: false
    t.datetime "updated_at", null: false
    t.index ["transcription_job_id", "group_number"], name: "index_page_groups_on_transcription_job_id_and_group_number", unique: true
    t.index ["transcription_job_id"], name: "index_page_groups_on_transcription_job_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transcription_jobs", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.integer "credits_charged", default: 0
    t.boolean "date_parsing_enabled", default: true, null: false
    t.text "error_message"
    t.datetime "expires_at"
    t.integer "page_count", default: 0, null: false
    t.datetime "reviewed_at"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "year_hint"
    t.index ["expires_at"], name: "index_transcription_jobs_on_expires_at"
    t.index ["status", "created_at"], name: "index_transcription_jobs_on_status_and_created_at"
    t.index ["user_id", "status"], name: "index_transcription_jobs_on_user_id_and_status"
    t.index ["user_id"], name: "index_transcription_jobs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.integer "credit_balance", default: 0, null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest"
    t.string "provider"
    t.string "stripe_customer_id"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "job_pages", "page_groups"
  add_foreign_key "job_pages", "transcription_jobs"
  add_foreign_key "journal_entries", "transcription_jobs"
  add_foreign_key "journal_entries", "users"
  add_foreign_key "page_credits", "transcription_jobs"
  add_foreign_key "page_credits", "users"
  add_foreign_key "page_groups", "transcription_jobs"
  add_foreign_key "sessions", "users"
  add_foreign_key "transcription_jobs", "users"
end
