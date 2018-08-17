class Event < ActiveRecord::Base
  include PgSearch
  pg_search_scope :search_address_and_buyer_details, :against => [:buyer_name ], :using => {
                    :tsearch => {:any_word => true}
                  }

  pg_search_scope :search_address_buyer_details_and_agent, :against => [:buyer_name, :agent_name], :using => {
                    :tsearch => {:any_word => true}
                  }
  pg_search_scope :search_address_and_agent_details, :against => [:agent_name ], :using => {
                  :tsearch => {:any_word => true}
                }               
  #default_scope { where(is_deleted: false) }
  default_scope { where(is_archived: false) }
  include EventsHelper

  EVENTS = {
    viewed: 2,
    property_tracking: 3,
    street_tracking: 4,
    locality_tracking: 5,
    interested_in_viewing: 6,
    interested_in_making_an_offer: 7,
    requested_message: 8,
    requested_callback: 9,
    requested_viewing: 10,
    deleted: 11,
    responded_to_email_request: 12,
    responded_to_callback_request: 13,
    responded_to_viewing_request: 14,
    qualifying_stage: 15,
    viewing_stage: 16,
    negotiating_stage: 17,
    offer_made_stage: 18,
    offer_accepted_stage: 19,
    closed_lost_stage: 20,
    closed_won_stage: 21,
    confidence_level: 22,
    visits: 23,
    conveyance_stage: 24,
    contract_exchange_stage: 25,
    completion_stage: 26,
    hot_property: 27,
    warm_property: 28,
    cold_property: 29,
    save_search_hash: 30,
    sold: 31,
    valuation_change: 32,
    dream_price_change: 33,
    requested_floorplan: 34
  }

  TYPE_OF_MATCH = {
    perfect: 1,
    potential: 2,
    unlikely: 3
  }

  PROPERTY_STATUS_TYPES = {
    'Green' => 1,
    'Amber' => 2,
    'Red'   => 3,
    'Rent'  => 4
  }

  PROPERTY_TYPES = {
    'Sale' => 1,
    'Rent' => 2
  }

  LISTING_TYPES = {
    'Normal' => 1,
    'Premium' => 2,
    'Featured' => 3
  }

  SERVICES = {
    'Sale' => 1,
    'Rent' => 2
  }

  REVERSE_LISTING_TYPES = LISTING_TYPES.invert

  REVERSE_STATUS_TYPES = PROPERTY_STATUS_TYPES.invert

  REVERSE_TYPE_OF_MATCH = TYPE_OF_MATCH.invert

  REVERSE_EVENTS = EVENTS.invert

  CONFIDENCE_ROWS = (1..5).to_a

  REVERSE_SERVICES = SERVICES.invert

  ENQUIRY_EVENTS = [
    :interested_in_viewing,
    :interested_in_making_an_offer,
    :requested_message,
    :requested_callback,
    :requested_viewing,
    :requested_floorplan
  ]

  TRACKING_EVENTS = [
    :property_tracking,
    :locality_tracking,
    :street_tracking
  ]

  QUALIFYING_STAGE_EVENTS = [
    :qualifying_stage,
    :viewing_stage,
    :offer_made_stage,
    :negotiating_stage,
    :offer_accepted_stage,
    :conveyance_stage,
    :contract_exchange_stage,
    :completion_stage,
    :closed_won_stage,
    :closed_lost_stage
  ]

  SUCCESSFUL_SEQUENCE_STAGES = [
    :qualifying_stage,
    :interested_in_viewing,
    :negotiating_stage,
    :conveyance_stage,
    :offer_made_stage,
    :offer_accepted_stage,
    :closed_won_stage,
    :contract_exchange_stage,
    :completion_stage,
    :sold
  ]

  UNSUCCESSFUL_SEQUENCE_STAGES = [
    :qualifying_stage,
    :interested_in_viewing,
    :negotiating_stage,
    :conveyance_stage,
    :offer_made_stage,
    :closed_lost_stage
  ]

  HOTNESS_EVENTS = [
    :hot_property,
    :warm_property,
    :cold_property
  ]

  PAGE_SIZE = 10

  BUYER_ENQUIRY_LIMIT = 10
end

