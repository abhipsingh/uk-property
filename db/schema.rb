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

ActiveRecord::Schema.define(version: 20170921184839) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "pg_trgm"

  create_table "ad_payment_histories", force: :cascade do |t|
    t.string   "hash_str",   null: false
    t.integer  "udprn",      null: false
    t.integer  "service",    null: false
    t.integer  "months",     null: false
    t.integer  "type_of_ad", null: false
    t.datetime "created_at", null: false
  end

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
  add_index "agents", ["name", "branches_url"], name: "index_agents_on_name_and_branches_url", unique: true, using: :btree

  create_table "agents_branches", force: :cascade do |t|
    t.string  "name",              limit: 255
    t.string  "property_urls",     limit: 255
    t.integer "agent_id"
    t.string  "address",           limit: 255
    t.string  "postcode"
    t.string  "district"
    t.text    "udprns",                        default: [], array: true
    t.string  "image_url"
    t.string  "email"
    t.string  "phone_number"
    t.string  "website"
    t.text    "verification_hash"
    t.jsonb   "invited_agents"
    t.string  "rent_email_suffix"
    t.string  "buy_email_suffix"
  end

  add_index "agents_branches", ["district"], name: "index_agents_branches_on_district", using: :btree
  add_index "agents_branches", ["name", "district", "property_urls"], name: "index_agents_branches_on_name_and_district_and_property_urls", unique: true, using: :btree
  add_index "agents_branches", ["postcode"], name: "index_agents_branches_on_postcode", using: :btree
  add_index "agents_branches", ["verification_hash"], name: "index_agents_branches_on_verification_hash", unique: true, using: :btree

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
    t.string   "first_name"
    t.string   "last_name"
    t.integer  "credit",              default: 0
  end

  add_index "agents_branches_assigned_agents", ["branch_id"], name: "index_agents_branches_assigned_agents_on_branch_id", using: :btree
  add_index "agents_branches_assigned_agents", ["email"], name: "index_agents_branches_assigned_agents_on_email", unique: true, using: :btree

  create_table "agents_branches_assigned_agents_leads", force: :cascade do |t|
    t.integer  "property_id"
    t.integer  "agent_id"
    t.string   "district"
    t.integer  "vendor_id"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.boolean  "submitted"
    t.integer  "property_status_type"
  end

  add_index "agents_branches_assigned_agents_leads", ["agent_id"], name: "index_agents_branches_assigned_agents_leads_on_agent_id", using: :btree
  add_index "agents_branches_assigned_agents_leads", ["district"], name: "index_agents_branches_assigned_agents_leads_on_district", using: :btree
  add_index "agents_branches_assigned_agents_leads", ["property_id", "agent_id", "vendor_id"], name: "prop_agent", unique: true, using: :btree
  add_index "agents_branches_assigned_agents_leads", ["property_id"], name: "index_agents_branches_assigned_agents_leads_on_property_id", using: :btree
  add_index "agents_branches_assigned_agents_leads", ["property_id"], name: "unique_vendor_property_claims", unique: true, using: :btree

  create_table "agents_branches_assigned_agents_quotes", force: :cascade do |t|
    t.datetime "deadline"
    t.integer  "agent_id"
    t.integer  "property_id"
    t.integer  "status"
    t.string   "payment_terms"
    t.jsonb    "quote_details"
    t.boolean  "service_required"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.string   "district"
    t.string   "vendor_name"
    t.string   "vendor_email"
    t.string   "vendor_mobile"
    t.string   "address"
    t.integer  "property_status_type"
    t.boolean  "is_assigned_agent"
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
    t.string   "tags",                               default: [], array: true
    t.string   "postcode"
    t.integer  "zoopla_id"
    t.text     "image_urls",                         default: [], array: true
    t.integer  "udprn"
    t.jsonb    "additional_details"
    t.string   "district"
    t.string   "county"
    t.string   "post_town"
    t.string   "dep_locality"
    t.string   "street"
    t.string   "area"
    t.string   "sector"
    t.string   "unit"
    t.string   "thoroughfare_descriptor"
    t.string   "double_dependent_locality"
    t.string   "dependent_locality"
    t.string   "dependent_thoroughfare_description"
  end

  add_index "agents_branches_crawled_properties", ["district"], name: "index_agents_branches_crawled_properties_on_district", using: :btree
  add_index "agents_branches_crawled_properties", ["latitude", "longitude"], name: "uniq_property", unique: true, using: :btree
  add_index "agents_branches_crawled_properties", ["postcode"], name: "index_agents_branches_crawled_properties_on_postcode", using: :btree
  add_index "agents_branches_crawled_properties", ["tags"], name: "index_agents_branches_crawled_properties_on_tags", using: :gin
  add_index "agents_branches_crawled_properties", ["zoopla_id"], name: "index_agents_branches_crawled_properties_on_zoopla_id", unique: true, using: :btree

  create_table "agents_branches_crawled_properties_buys", force: :cascade do |t|
    t.string   "price"
    t.string   "description"
    t.string   "locality"
    t.string   "agent_url"
    t.float    "latitude"
    t.float    "longitude"
    t.text     "image_urls",                         default: [],              array: true
    t.text     "floorplan_urls",                     default: [],              array: true
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "agent_id"
    t.string   "postcode"
    t.string   "county"
    t.string   "post_town"
    t.string   "dep_locality"
    t.string   "street"
    t.string   "area"
    t.string   "district"
    t.string   "sector"
    t.string   "unit"
    t.string   "thoroughfare_descriptor"
    t.string   "double_dependent_locality"
    t.string   "dependent_locality"
    t.string   "dependent_thoroughfare_description"
  end

  create_table "agents_branches_crawled_properties_rents", force: :cascade do |t|
    t.string   "price"
    t.string   "locality"
    t.string   "description"
    t.text     "image_urls",                         default: [],              array: true
    t.string   "agent_url"
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "agent_id"
    t.string   "postcode"
    t.string   "county"
    t.string   "post_town"
    t.string   "dep_locality"
    t.string   "street"
    t.string   "area"
    t.string   "district"
    t.string   "sector"
    t.string   "unit"
    t.string   "thoroughfare_descriptor"
    t.string   "double_dependent_locality"
    t.string   "dependent_locality"
    t.string   "dependent_thoroughfare_description"
  end

  create_table "agents_branches_on_the_market_rents", force: :cascade do |t|
    t.string   "name"
    t.string   "address"
    t.string   "phone"
    t.string   "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "agent_url"
  end

  add_index "agents_branches_on_the_market_rents", ["name"], name: "index_agents_branches_on_the_market_rents_on_name", unique: true, using: :btree

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

  create_table "buyer_searches", force: :cascade do |t|
    t.integer  "buyer_id"
    t.jsonb    "search_hash"
    t.integer  "match_type"
    t.integer  "listing_type"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "events", force: :cascade do |t|
    t.integer  "agent_id"
    t.integer  "udprn"
    t.jsonb    "message"
    t.integer  "type_of_match",            limit: 2
    t.integer  "event",                    limit: 2
    t.integer  "buyer_id"
    t.string   "buyer_name"
    t.string   "buyer_email"
    t.string   "buyer_mobile"
    t.string   "agent_name"
    t.string   "agent_email"
    t.string   "agent_mobile"
    t.string   "address"
    t.datetime "created_at",                                         null: false
    t.boolean  "is_deleted",                         default: false
    t.integer  "property_status_type",               default: 0
    t.boolean  "is_archived",                        default: false
    t.integer  "stage",                    limit: 2, default: 15
    t.integer  "rating",                   limit: 2, default: 29
    t.datetime "scheduled_visit_time"
    t.integer  "offer_price"
    t.date     "offer_date"
    t.date     "expected_completion_date"
  end

  create_table "events_enquiry_stat_buyers", force: :cascade do |t|
    t.integer "buyer_id",                  null: false
    t.integer "event",                     null: false
    t.integer "enquiry_count", default: 0, null: false
  end

  create_table "events_enquiry_stat_properties", force: :cascade do |t|
    t.integer "udprn",                     null: false
    t.integer "event",                     null: false
    t.integer "enquiry_count", default: 0, null: false
  end

  create_table "events_hotnesses", force: :cascade do |t|
    t.integer  "event"
    t.integer  "udprn"
    t.integer  "buyer_id"
    t.integer  "agent_id"
    t.integer  "service"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "events_stages", force: :cascade do |t|
    t.integer  "event"
    t.integer  "buyer_id"
    t.integer  "agent_id"
    t.integer  "property_status_type"
    t.jsonb    "message"
    t.datetime "created_at",           null: false
    t.integer  "udprn"
  end

  create_table "events_tracks", force: :cascade do |t|
    t.integer  "type_of_tracking"
    t.integer  "buyer_id"
    t.integer  "agent_id"
    t.integer  "udprn"
    t.integer  "property_status_type", default: 1
    t.string   "hash_str"
    t.boolean  "active",               default: true
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  create_table "events_views", force: :cascade do |t|
    t.integer  "udprn",      null: false
    t.integer  "buyer_id",   null: false
    t.integer  "agent_id"
    t.integer  "vendor_id"
    t.integer  "service"
    t.datetime "created_at", null: false
  end

  create_table "invited_agents", force: :cascade do |t|
    t.string   "email"
    t.integer  "udprn"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "pb_details", force: :cascade do |t|
    t.jsonb    "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "property_ads", force: :cascade do |t|
    t.integer  "property_id"
    t.string   "hash_str"
    t.integer  "ad_type"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.integer  "service"
    t.datetime "expiry_at"
  end

  add_index "property_ads", ["property_id", "ad_type", "hash_str"], name: "index_property_ads_on_property_id_and_ad_type_and_hash_str", unique: true, using: :btree

  create_table "property_buyers", force: :cascade do |t|
    t.jsonb    "searches",          default: [], null: false
    t.string   "name"
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
    t.string   "first_name"
    t.string   "last_name"
    t.string   "property_types",    default: [],              array: true
    t.integer  "min_beds"
    t.integer  "max_beds"
    t.integer  "min_baths"
    t.integer  "max_baths"
    t.integer  "min_receptions"
    t.integer  "max_receptions"
    t.jsonb    "locations"
    t.jsonb    "biggest_problems"
    t.integer  "viewings"
    t.integer  "enquiries"
  end

  add_index "property_buyers", ["email_id"], name: "index_property_buyers_on_email_id", unique: true, using: :btree

  create_table "property_events", force: :cascade do |t|
    t.jsonb    "attr_hash",  default: {}, null: false
    t.integer  "udprn",                   null: false
    t.datetime "created_at",              null: false
  end

  create_table "property_historical_details", force: :cascade do |t|
    t.string  "uuid"
    t.integer "price"
    t.string  "date"
    t.integer "udprn"
    t.string  "property_type"
    t.string  "age"
    t.string  "duration"
  end

  create_table "sold_properties", force: :cascade do |t|
    t.integer  "udprn",           null: false
    t.integer  "sale_price",      null: false
    t.date     "completion_date"
    t.integer  "vendor_id",       null: false
    t.integer  "buyer_id",        null: false
    t.integer  "agent_id",        null: false
    t.datetime "created_at",      null: false
  end

  create_table "stripe_payments", force: :cascade do |t|
    t.integer  "entity_id"
    t.string   "entity_type"
    t.integer  "amount"
    t.datetime "created_at",  null: false
  end

  create_table "uk_properties", force: :cascade do |t|
    t.string  "post_code"
    t.string  "post_town"
    t.string  "dependent_locality"
    t.string  "double_dependent_locality"
    t.string  "thoroughfare_descriptor"
    t.string  "dependent_thoroughfare_description"
    t.string  "building_number"
    t.string  "building_name"
    t.string  "sub_building_name"
    t.string  "po_box_no"
    t.string  "department_name"
    t.string  "organization_name"
    t.integer "udprn"
    t.string  "postcode_type"
    t.string  "su_organisation_indicator"
    t.string  "delivery_point_suffix"
    t.string  "building_text"
    t.string  "area"
    t.string  "district"
    t.string  "sector"
    t.string  "unit"
    t.string  "county"
  end

  add_index "uk_properties", ["post_code"], name: "trgm_postcode_indx", using: :gist
  add_index "uk_properties", ["udprn"], name: "index_uk_properties_on_udprn", unique: true, using: :btree

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
    t.string   "first_name"
    t.string   "last_name"
  end

  add_index "vendors", ["email"], name: "index_vendors_on_email", unique: true, using: :btree
  add_index "vendors", ["property_id"], name: "index_vendors_on_property_id", unique: true, using: :btree

  create_table "verification_hashes", force: :cascade do |t|
    t.integer  "entity_id"
    t.string   "entity_type"
    t.string   "email"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.text     "hash_value"
    t.integer  "udprn"
  end

  add_index "verification_hashes", ["hash_value"], name: "index_verification_hashes_on_hash_value", unique: true, using: :btree

  create_table "visited_localities", force: :cascade do |t|
    t.string   "locality"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "visited_localities", ["locality"], name: "index_visited_localities_on_locality", using: :btree

  create_table "visited_urls", force: :cascade do |t|
    t.string   "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "visited_urls", ["url"], name: "index_visited_urls_on_url", using: :btree

end
