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

ActiveRecord::Schema[8.0].define(version: 2025_07_09_063929) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "vector"

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

  create_table "ai_settings", force: :cascade do |t|
    t.string "provider", null: false
    t.string "api_key"
    t.string "model_id", null: false
    t.decimal "monthly_budget", precision: 10, scale: 2, default: "0.0"
    t.decimal "usage_this_month", precision: 10, scale: 2, default: "0.0"
    t.boolean "is_active", default: false, null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active", "provider"], name: "index_ai_settings_on_active_provider"
    t.index ["is_active"], name: "index_ai_settings_on_is_active"
    t.index ["last_used_at"], name: "index_ai_settings_on_last_used"
    t.index ["provider", "model_id"], name: "index_ai_settings_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ai_settings_on_provider"
    t.index ["usage_this_month"], name: "index_ai_settings_on_usage"
  end

# Could not dump table "articles" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


  create_table "chapters", force: :cascade do |t|
    t.bigint "edition_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "sort_order", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition_id", "number"], name: "index_chapters_on_edition_id_and_number", unique: true
    t.index ["edition_id", "sort_order"], name: "index_chapters_on_edition_id_and_sort_order"
    t.index ["edition_id"], name: "index_chapters_on_edition_id"
    t.index ["is_active", "edition_id"], name: "index_chapters_on_active_edition"
  end

  create_table "clauses", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.integer "number", null: false
    t.text "content", null: false
    t.string "clause_type", default: "paragraph"
    t.integer "sort_order", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "number"], name: "index_clauses_on_article_id_and_number", unique: true
    t.index ["article_id", "sort_order"], name: "index_clauses_on_article_id_and_sort_order"
    t.index ["article_id"], name: "index_clauses_on_article_id"
    t.index ["clause_type"], name: "index_clauses_on_clause_type"
    t.index ["is_active", "article_id"], name: "index_clauses_on_active_article"
  end

  create_table "conversations", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "title"
    t.datetime "last_message_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at", "last_message_at"], name: "index_conversations_on_expires_last_message"
    t.index ["expires_at"], name: "index_conversations_on_expires_at"
    t.index ["last_message_at"], name: "index_conversations_on_last_message_at"
    t.index ["session_id"], name: "index_conversations_on_session_id", unique: true
  end

  create_table "editions", force: :cascade do |t|
    t.integer "number", null: false
    t.string "title", null: false
    t.text "description"
    t.integer "sort_order", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_editions_on_number", unique: true
    t.index ["sort_order"], name: "index_editions_on_sort_order"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.integer "tokens_used", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["role", "conversation_id"], name: "index_messages_on_role_conversation"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tokens_used"], name: "index_messages_on_tokens_used"
  end

  create_table "regulations", force: :cascade do |t|
    t.bigint "chapter_id", null: false
    t.integer "number", null: false
    t.string "title", null: false
    t.text "content"
    t.string "regulation_code", null: false
    t.string "status", default: "active"
    t.integer "sort_order", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id", "number"], name: "index_regulations_on_chapter_id_and_number", unique: true
    t.index ["chapter_id", "sort_order"], name: "index_regulations_on_chapter_id_and_sort_order"
    t.index ["chapter_id"], name: "index_regulations_on_chapter_id"
    t.index ["is_active", "chapter_id"], name: "index_regulations_on_active_chapter"
    t.index ["regulation_code"], name: "index_regulations_on_regulation_code", unique: true
    t.index ["status", "chapter_id"], name: "index_regulations_on_status_chapter"
    t.index ["status"], name: "index_regulations_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "name"
    t.string "role"
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.integer "failed_attempts", default: 0
    t.datetime "locked_until"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["failed_attempts"], name: "index_users_on_failed_attempts"
    t.index ["last_login_at"], name: "index_users_on_last_login_at"
    t.index ["locked_until"], name: "index_users_on_locked_until"
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "regulations"
  add_foreign_key "chapters", "editions"
  add_foreign_key "clauses", "articles"
  add_foreign_key "messages", "conversations"
  add_foreign_key "regulations", "chapters"
end
