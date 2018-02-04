module Enquiries
  class BuyerService
    include EnquiryInfoHelper

    attr_accessor :buyer_id, :udprn, :agent_id

    def initialize(buyer_id: buyer, udprn: property_id=nil, agent_id: agent=nil)
      @buyer_id ||=  buyer_id
      @udprn ||=  udprn
      @agent_id ||= agent_id
    end

    def historical_enquiries(enquiry_type: enquiry=nil, type_of_match: match=nil, property_status_type: status=nil, hash_str: str=nil, verification_status: is_verified=nil, last_time: time=nil, page_number: page=0, count: count_flag=false)
      result = []
      events = Event::ENQUIRY_EVENTS.map { |e| Event::EVENTS[e] }

      ### Dummy agent id to form the query. Is removed in the next line
      ### By Default enable search for all buyers
      query = filtered_agent_query agent_id: 1, last_time: last_time, buyer_id: buyer_id, type_of_match: type_of_match
      query = query.where(buyer_id: buyer_id)
      query = query.unscope(where: :agent_id)
      query = query.unscope(where: :is_archived)
      query = query.where(event: Event::EVENTS[enquiry_type.to_sym]) if enquiry_type

      ### Search, verification status and property status type filters
      udprns = []
      if hash_str || property_status_type || verification_status
        res = query.to_a
        res_udprns = res.map(&:udprn).uniq
        udprns = fetch_udprns(hash_str, res_udprns, property_status_type, verification_status)
        query = query.where(udprn: udprns)
      end

      total_rows = []
      if count
        total_rows = query.count
      else
        query = query.order('created_at DESC')
        query = query.to_a
        total_rows = query
        #total_rows = query.limit(PAGE_SIZE).offset(page_number.to_i*PAGE_SIZE)
        total_rows = self.class.process_enquiries_result(total_rows)
      end
      total_rows
    end
  
  end

end

