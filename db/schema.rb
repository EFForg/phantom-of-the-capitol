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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 10) do

  create_table "application_settings", :force => true do |t|
    t.string   "key"
    t.text     "value"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "application_settings", ["key"], :name => "index_application_settings_on_key", :unique => true

  create_table "campaign_tags", :force => true do |t|
    t.string "name"
  end

  create_table "congress_member_actions", :force => true do |t|
    t.integer "congress_member_id"
    t.integer "step"
    t.string  "action"
    t.string  "name"
    t.string  "selector"
    t.string  "value"
    t.boolean "required",            :default => false
    t.integer "maxlength"
    t.string  "captcha_selector"
    t.string  "captcha_id_selector"
    t.text    "options"
  end

  create_table "congress_members", :force => true do |t|
    t.string   "bioguide_id"
    t.string   "success_criteria"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "congress_members", ["bioguide_id"], :name => "index_congress_members_on_bioguide_id", :unique => true

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0, :null => false
    t.integer  "attempts",   :default => 0, :null => false
    t.text     "handler",                   :null => false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at",                :null => false
    t.datetime "updated_at",                :null => false
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "fill_statuses", :force => true do |t|
    t.integer  "congress_member_id"
    t.integer  "campaign_tag_id"
    t.datetime "created_at",         :null => false
    t.datetime "updated_at",         :null => false
    t.string   "status"
    t.string   "extra"
  end

end
