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

ActiveRecord::Schema[8.0].define(version: 2026_04_08_131000) do
  create_table "chobatsu_reports", force: :cascade do |t|
    t.date "ceremony_date", null: false
    t.integer "evangelism_meeting_id", null: false
    t.string "assistant_name", null: false
    t.integer "participant_count", null: false
    t.integer "serial_number_from", null: false
    t.integer "serial_number_to", null: false
    t.integer "merit_fee_total", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ceremony_date"], name: "index_chobatsu_reports_on_ceremony_date"
    t.index ["evangelism_meeting_id"], name: "index_chobatsu_reports_on_evangelism_meeting_id"
    t.index ["serial_number_from", "serial_number_to"], name: "idx_on_serial_number_from_serial_number_to_786d8ec233"
  end

  create_table "evangelism_meetings", force: :cascade do |t|
    t.string "name", null: false
    t.string "color_code", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_evangelism_meetings_on_name", unique: true
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
  end

  add_foreign_key "chobatsu_reports", "evangelism_meetings"
end
