module Rent
  class Quote < ActiveRecord::Base
    belongs_to :agent, class_name: 'Agents::Branches::AssignedAgent', foreign_key: 'agent_id'
    belongs_to :vendor, class_name: 'Vendor', foreign_key: 'vendor_id'
  
    STATUS_HASH = {
      'New' => 1,
      'Lost' => 2,
      'Won' => 3
    }
  
    #MAX_AGENT_QUOTE_WAIT_TIME = 48.hours
    MAX_AGENT_QUOTE_WAIT_TIME = 10.minutes
    #MAX_VENDOR_QUOTE_WAIT_TIME = 72.hours
    MAX_VENDOR_QUOTE_WAIT_TIME = 20.minutes
    VENDOR_LIMIT = 30
    REVERSE_STATUS_HASH = STATUS_HASH.invert
  
    PAYMENT_TERMS_HASH = {
      "Pay on completion"=> 1,
      "Pay upfront"=> 2
    }

    REVERSE_PAYMENT_TERMS_HASH = PAYMENT_TERMS_HASH.invert

  end
end

