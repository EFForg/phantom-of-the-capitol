# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 14) do

  create_table "application_settings", force: :cascade do |t|
    t.string   "key",        limit: 255
    t.text     "value",      limit: 65535
    t.datetime "created_at",               null: false
    t.datetime "updated_at",               null: false
  end

  add_index "application_settings", ["key"], name: "index_application_settings_on_key", unique: true, using: :btree

  create_table "campaign_tags", force: :cascade do |t|
    t.string "name", limit: 255
  end

  create_table "congress_member_actions", force: :cascade do |t|
    t.integer "congress_member_id",  limit: 4
    t.integer "step",                limit: 4
    t.string  "action",              limit: 255
    t.string  "name",                limit: 255
    t.string  "selector",            limit: 255
    t.string  "value",               limit: 255
    t.boolean "required",            default: false
    t.integer "maxlength",           limit: 4
    t.string  "captcha_selector",    limit: 255
    t.string  "captcha_id_selector", limit: 255
    t.text    "options",             limit: 65535
  end

  create_table "congress_members", force: :cascade do |t|
    t.string   "bioguide_id",      limit: 255
    t.string   "success_criteria", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "congress_members", ["bioguide_id"], name: "index_congress_members_on_bioguide_id", unique: true, using: :btree

  create_table "data_sources", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "path",          limit: 255
    t.string   "yaml_subpath",  limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "latest_commit", limit: 255
    t.string   "prefix",        limit: 255
  end

  add_index "data_sources", ["name"], name: "index_data_sources_on_name", using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   limit: 4,     default: 0, null: false
    t.integer  "attempts",   limit: 4,     default: 0, null: false
    t.text     "handler",    limit: 65535,             null: false
    t.text     "last_error", limit: 65535
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "fill_statuses", force: :cascade do |t|
    t.integer  "congress_member_id", limit: 4
    t.integer  "campaign_tag_id",    limit: 4
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "status",             limit: 255
    t.string   "extra",              limit: 255
  end

end
