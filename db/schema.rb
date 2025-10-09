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

ActiveRecord::Schema[8.0].define(version: 2025_10_07_130756) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.string "color"
    t.integer "parent_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_category_id"], name: "index_categories_on_parent_category_id"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "goal_completions", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.date "date", null: false
    t.boolean "achieved", default: false, null: false
    t.integer "actual_minutes", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["achieved", "date"], name: "index_goal_completions_on_achieved_and_date"
    t.index ["date"], name: "index_goal_completions_on_date"
    t.index ["goal_id", "date"], name: "index_goal_completions_on_goal_and_date", unique: true
    t.index ["goal_id"], name: "index_goal_completions_on_goal_id"
    t.check_constraint "actual_minutes >= 0", name: "non_negative_actual_minutes"
    t.check_constraint "date <= CURRENT_DATE", name: "no_future_completions"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id"
    t.string "goal_type", null: false
    t.integer "target_minutes", null: false
    t.integer "hour"
    t.string "days_of_week", default: "[\"Monday\",\"Tuesday\",\"Wednesday\",\"Thursday\",\"Friday\",\"Saturday\",\"Sunday\"]"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_goals_on_category_id"
    t.index ["user_id", "active"], name: "index_goals_on_user_and_active"
    t.index ["user_id", "goal_type"], name: "index_goals_on_user_and_type"
    t.index ["user_id"], name: "index_goals_on_user_id"
    t.check_constraint "goal_type::text = 'specific_hour'::text AND hour IS NOT NULL AND hour >= 0 AND hour <= 23 OR goal_type::text <> 'specific_hour'::text AND hour IS NULL", name: "hour_requirement"
    t.check_constraint "goal_type::text = ANY (ARRAY['daily'::character varying, 'weekly'::character varying, 'specific_hour'::character varying]::text[])", name: "valid_goal_type"
    t.check_constraint "target_minutes > 0", name: "positive_target"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "category_id", null: false
    t.date "date", null: false
    t.integer "hour", null: false
    t.integer "duration_minutes", default: 60, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_time_entries_on_category_id"
    t.index ["user_id", "date", "hour"], name: "index_time_entries_on_user_date_hour", unique: true
    t.index ["user_id", "date"], name: "index_time_entries_on_user_date"
    t.index ["user_id", "hour"], name: "index_time_entries_on_user_hour"
    t.index ["user_id"], name: "index_time_entries_on_user_id"
    t.check_constraint "date <= CURRENT_DATE", name: "no_future_entries"
    t.check_constraint "duration_minutes >= 1 AND duration_minutes <= 60", name: "valid_duration"
    t.check_constraint "hour >= 0 AND hour <= 23", name: "valid_hour"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "time_zone"
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "categories", "categories", column: "parent_category_id"
  add_foreign_key "categories", "users"
  add_foreign_key "goal_completions", "goals"
  add_foreign_key "goals", "categories"
  add_foreign_key "goals", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_entries", "categories"
  add_foreign_key "time_entries", "users"
end
