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

ActiveRecord::Schema[8.0].define(version: 2026_04_09_133000) do
  create_table "chobatsu_reports", force: :cascade do |t|
    t.date "ceremony_date", null: false
    t.integer "evangelism_meeting_id", null: false
    t.string "assistant_name"
    t.integer "participant_count", null: false
    t.integer "serial_number_from", null: false
    t.integer "serial_number_to", null: false
    t.integer "merit_fee_total", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "region_id", default: 1, null: false
    t.integer "event_id", default: 1, null: false
    t.integer "user_id"
    t.index ["ceremony_date"], name: "index_chobatsu_reports_on_ceremony_date"
    t.index ["evangelism_meeting_id"], name: "index_chobatsu_reports_on_evangelism_meeting_id"
    t.index ["event_id"], name: "index_chobatsu_reports_on_event_id"
    t.index ["region_id"], name: "index_chobatsu_reports_on_region_id"
    t.index ["serial_number_from", "serial_number_to"], name: "idx_on_serial_number_from_serial_number_to_786d8ec233"
    t.index ["user_id"], name: "index_chobatsu_reports_on_user_id"
  end

  create_table "evangelism_meetings", force: :cascade do |t|
    t.string "name", null: false
    t.string "color_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active", default: true, null: false
    t.integer "display_order"
    t.integer "region_id", null: false
    t.index ["active"], name: "index_evangelism_meetings_on_active"
    t.index ["display_order"], name: "index_evangelism_meetings_on_display_order"
    t.index ["name"], name: "index_evangelism_meetings_on_name", unique: true
    t.index ["region_id"], name: "index_evangelism_meetings_on_region_id"
  end

  create_table "event_details", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "region_id", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "total_serial_count", default: 1667, null: false
    t.index ["event_id", "region_id"], name: "index_event_details_on_event_id_and_region_id", unique: true
    t.index ["event_id"], name: "index_event_details_on_event_id"
    t.index ["region_id"], name: "index_event_details_on_region_id"
  end

  create_table "events", force: :cascade do |t|
    t.text "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_events_on_name", unique: true
  end

  create_table "regions", force: :cascade do |t|
    t.text "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_regions_on_name", unique: true
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.text "email", null: false
    t.string "password_digest", null: false
    t.text "name", null: false
    t.integer "region_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["region_id"], name: "index_users_on_region_id"
  end

  add_foreign_key "chobatsu_reports", "evangelism_meetings"
  add_foreign_key "chobatsu_reports", "events"
  add_foreign_key "chobatsu_reports", "regions"
  add_foreign_key "chobatsu_reports", "users"
  add_foreign_key "evangelism_meetings", "regions"
  add_foreign_key "event_details", "events"
  add_foreign_key "event_details", "regions"
  add_foreign_key "users", "regions"
end
