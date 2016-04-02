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

ActiveRecord::Schema.define(version: 20160402063807) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "agents", force: :cascade do |t|
    t.string "name",         limit: 255
    t.string "branches_url", limit: 255
  end

  create_table "agents_branches", force: :cascade do |t|
    t.string  "name",          limit: 255
    t.string  "property_urls", limit: 255
    t.integer "agent_id"
    t.string  "address",       limit: 255
  end

  create_table "agents_branches_crawled_properties", force: :cascade do |t|
    t.text     "html"
    t.jsonb    "stored_response"
    t.integer  "branch_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "latitude"
    t.decimal  "longitude"
  end

  add_index "agents_branches_crawled_properties", ["latitude", "longitude"], name: "uniq_property", unique: true, using: :btree

  create_table "property_historical_details", force: :cascade do |t|
    t.string  "uuid"
    t.integer "price"
    t.string  "date"
    t.string  "udprn"
  end

  create_table "users_email_users", force: :cascade do |t|
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.string   "email",              limit: 255, null: false
    t.string   "encrypted_password", limit: 128, null: false
    t.string   "confirmation_token", limit: 128
    t.string   "remember_token",     limit: 128, null: false
  end

  add_index "users_email_users", ["email"], name: "index_users_email_users_on_email", using: :btree
  add_index "users_email_users", ["remember_token"], name: "index_users_email_users_on_remember_token", using: :btree

end
