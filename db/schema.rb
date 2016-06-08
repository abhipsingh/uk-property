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

ActiveRecord::Schema.define(version: 20160524122702) do

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
    t.string  "postcode"
    t.string  "district"
    t.text    "udprns",                    default: [], array: true
  end

  add_index "agents_branches", ["district"], name: "index_agents_branches_on_district", using: :btree
  add_index "agents_branches", ["postcode"], name: "index_agents_branches_on_postcode", using: :btree

  create_table "agents_branches_crawled_properties", force: :cascade do |t|
    t.text     "html"
    t.jsonb    "stored_response"
    t.integer  "branch_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.decimal  "latitude"
    t.decimal  "longitude"
    t.string   "tags",            default: [], array: true
  end

  add_index "agents_branches_crawled_properties", ["latitude", "longitude"], name: "uniq_property", unique: true, using: :btree
  add_index "agents_branches_crawled_properties", ["tags"], name: "index_agents_branches_crawled_properties_on_tags", using: :gin

  create_table "property_buyers", force: :cascade do |t|
    t.jsonb    "searches",       default: [], null: false
    t.string   "name",                        null: false
    t.string   "email_id",                    null: false
    t.string   "account_type",                null: false
    t.jsonb    "visited_udprns", default: [], null: false
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "property_buyers", ["email_id"], name: "index_property_buyers_on_email_id", unique: true, using: :btree

  create_table "property_historical_details", force: :cascade do |t|
    t.string  "uuid"
    t.integer "price"
    t.string  "date"
    t.string  "udprn"
  end

  add_index "property_historical_details", ["udprn"], name: "index_property_historical_details_on_udprn", using: :btree

  create_table "property_users", force: :cascade do |t|
    t.string   "full_name",              default: "", null: false
    t.string   "image",                  default: "", null: false
    t.string   "email",                  default: "", null: false
    t.string   "encrypted_password",     default: "", null: false
    t.string   "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "unconfirmed_email"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.string   "provider"
    t.string   "uid"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "profile_type"
  end

  add_index "property_users", ["confirmation_token"], name: "index_property_users_on_confirmation_token", unique: true, using: :btree
  add_index "property_users", ["email"], name: "index_property_users_on_email", unique: true, using: :btree
  add_index "property_users", ["provider"], name: "index_property_users_on_provider", using: :btree
  add_index "property_users", ["reset_password_token"], name: "index_property_users_on_reset_password_token", unique: true, using: :btree
  add_index "property_users", ["uid"], name: "index_property_users_on_uid", using: :btree

  create_table "registrations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "temp_property_details", force: :cascade do |t|
    t.jsonb    "details"
    t.string   "session_id"
    t.string   "udprn"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "vendor_id"
    t.integer  "agent_id"
    t.jsonb    "agent_services"
    t.integer  "user_id"
  end

  add_index "temp_property_details", ["user_id"], name: "index_temp_property_details_on_user_id", using: :btree

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
