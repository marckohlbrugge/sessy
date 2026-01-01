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

ActiveRecord::Schema[8.1].define(version: 2026_01_01_090207) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.string "bounce_type"
    t.datetime "created_at", null: false
    t.datetime "event_at", null: false
    t.json "event_data", default: {}
    t.string "event_type", null: false
    t.bigint "message_id", null: false
    t.json "raw_payload", default: {}
    t.string "recipient_email", null: false
    t.string "ses_message_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_id"
    t.index ["bounce_type"], name: "index_events_on_bounce_type"
    t.index ["event_at"], name: "index_events_on_event_at"
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["message_id"], name: "index_events_on_message_id"
    t.index ["recipient_email"], name: "index_events_on_recipient_email"
    t.index ["ses_message_id", "event_type", "recipient_email", "event_at"], name: "index_ses_events_on_deduplication_key", unique: true
    t.index ["webhook_id"], name: "index_events_on_webhook_id"
  end

  create_table "messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "events_count", default: 0, null: false
    t.json "mail_metadata", default: {}
    t.datetime "sent_at"
    t.string "ses_message_id", null: false
    t.string "source_email"
    t.bigint "source_id"
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["sent_at"], name: "index_messages_on_sent_at"
    t.index ["ses_message_id"], name: "index_messages_on_ses_message_id", unique: true
    t.index ["source_email"], name: "index_messages_on_source_email"
    t.index ["source_id"], name: "index_messages_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "color", default: "blue"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "retention_days"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_sources_on_token", unique: true
  end

  create_table "webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "processed_at"
    t.json "raw_payload", default: {}, null: false
    t.string "sns_message_id", null: false
    t.datetime "sns_timestamp", null: false
    t.string "sns_type", null: false
    t.datetime "updated_at", null: false
    t.index ["processed_at"], name: "index_webhooks_on_processed_at"
    t.index ["sns_message_id"], name: "index_webhooks_on_sns_message_id", unique: true
  end

  add_foreign_key "events", "messages"
  add_foreign_key "events", "webhooks"
  add_foreign_key "messages", "sources"
end
