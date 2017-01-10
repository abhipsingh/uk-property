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

ActiveRecord::Schema.define(version: 20170109153012) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "agents", force: :cascade do |t|
    t.string  "name",         limit: 255
    t.string  "branches_url", limit: 255
    t.integer "group_id"
    t.string  "email"
    t.string  "phone_number"
    t.string  "website"
    t.string  "address"
    t.string  "image_url"
  end

  add_index "agents", ["group_id"], name: "index_agents_on_group_id", using: :btree

  create_table "agents_branches", force: :cascade do |t|
    t.string  "name",          limit: 255
    t.string  "property_urls", limit: 255
    t.integer "agent_id"
    t.string  "address",       limit: 255
    t.string  "postcode"
    t.string  "district"
    t.text    "udprns",                    default: [], array: true
    t.string  "image_url"
    t.string  "email"
    t.string  "phone_number"
    t.string  "website"
  end

  add_index "agents_branches", ["district"], name: "index_agents_branches_on_district", using: :btree
  add_index "agents_branches", ["postcode"], name: "index_agents_branches_on_postcode", using: :btree

  create_table "agents_branches_assigned_agents", force: :cascade do |t|
    t.string   "name"
    t.string   "email"
    t.string   "mobile"
    t.integer  "branch_id"
    t.string   "title"
    t.string   "office_phone_number"
    t.string   "mobile_phone_number"
    t.string   "image_url"
    t.jsonb    "invited_agents"
    t.string   "password"
    t.string   "password_digest"
    t.string   "provider"
    t.string   "uid"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
  end

  add_index "agents_branches_assigned_agents", ["branch_id"], name: "index_agents_branches_assigned_agents_on_branch_id", using: :btree

  create_table "agents_branches_assigned_agents_leads", force: :cascade do |t|
    t.integer  "property_id"
    t.integer  "agent_id"
    t.string   "district"
    t.integer  "vendor_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "agents_branches_assigned_agents_leads", ["agent_id"], name: "index_agents_branches_assigned_agents_leads_on_agent_id", using: :btree
  add_index "agents_branches_assigned_agents_leads", ["district"], name: "index_agents_branches_assigned_agents_leads_on_district", using: :btree
  add_index "agents_branches_assigned_agents_leads", ["property_id", "agent_id", "vendor_id"], name: "prop_agent", unique: true, using: :btree
  add_index "agents_branches_assigned_agents_leads", ["property_id"], name: "index_agents_branches_assigned_agents_leads_on_property_id", using: :btree

  create_table "agents_branches_assigned_agents_quotes", force: :cascade do |t|
    t.datetime "deadline"
    t.integer  "agent_id"
    t.integer  "property_id"
    t.integer  "status"
    t.string   "payment_terms"
    t.jsonb    "quote_details"
    t.boolean  "service_required"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "district"
    t.string   "vendor_name"
    t.string   "vendor_email"
    t.string   "vendor_mobile"
    t.string   "address"
  end

  add_index "agents_branches_assigned_agents_quotes", ["district"], name: "index_agents_branches_assigned_agents_quotes_on_district", using: :btree

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

  create_table "agents_groups", force: :cascade do |t|
    t.string   "name"
    t.string   "image_url"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "website"
    t.string   "email"
    t.string   "phone_number"
    t.string   "address"
  end

  create_table "events", force: :cascade do |t|
    t.integer  "agent_id"
    t.integer  "udprn"
    t.jsonb    "message"
    t.integer  "type_of_match", limit: 2
    t.integer  "event",         limit: 2
    t.integer  "buyer_id"
    t.string   "buyer_name"
    t.string   "buyer_email"
    t.string   "buyer_mobile"
    t.string   "agent_name"
    t.string   "agent_email"
    t.string   "agent_mobile"
    t.string   "address"
    t.datetime "created_at",              null: false
  end

  create_table "messages", force: :cascade do |t|
    t.text     "content"
    t.integer  "from"
    t.integer  "to"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "messages", ["from"], name: "index_messages_on_from", using: :btree
  add_index "messages", ["to"], name: "index_messages_on_to", using: :btree

  create_table "property_ads", force: :cascade do |t|
    t.integer  "property_id"
    t.string   "hash_str"
    t.integer  "ad_type"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "property_ads", ["property_id", "ad_type", "hash_str"], name: "index_property_ads_on_property_id_and_ad_type_and_hash_str", unique: true, using: :btree

  create_table "property_buyers", force: :cascade do |t|
    t.jsonb    "searches",          default: [], null: false
    t.string   "name",                           null: false
    t.string   "email_id",                       null: false
    t.string   "account_type",                   null: false
    t.jsonb    "visited_udprns",    default: [], null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "status_id"
    t.boolean  "chain_free"
    t.string   "full_name"
    t.string   "email"
    t.string   "mobile"
    t.integer  "status"
    t.integer  "buying_status"
    t.integer  "funding"
    t.integer  "mortgage_approval"
    t.integer  "biggest_problem"
    t.string   "password"
    t.string   "password_digest"
    t.string   "image_url"
    t.integer  "budget_from"
    t.integer  "budget_to"
    t.string   "provider"
    t.string   "uid"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
    t.integer  "vendor_id"
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
    t.jsonb    "saved_searches",         default: []
    t.integer  "shortlisted_flat_ids",   default: [],              array: true
    t.jsonb    "messages",               default: []
    t.jsonb    "callbacks",              default: []
    t.jsonb    "viewings",               default: []
    t.jsonb    "offers",                 default: []
    t.jsonb    "matrix_searches",        default: []
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

  create_table "vendors", force: :cascade do |t|
    t.string   "full_name"
    t.integer  "property_id"
    t.string   "email"
    t.string   "mobile"
    t.integer  "status"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "image_url"
    t.string   "password"
    t.string   "password_digest"
    t.string   "name"
    t.string   "provider"
    t.string   "uid"
    t.string   "oauth_token"
    t.datetime "oauth_expires_at"
    t.integer  "buyer_id"
  end

end
