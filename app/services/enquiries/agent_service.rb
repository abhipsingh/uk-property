module Enquiries
  class AgentService
    include EnquiryInfoHelper

    attr_accessor :agent_id, :udprn, :buyer_id

    def initialize(agent_id: agent, udprn: udprn=nil, buyer_id: buyer=nil)
      @agent_id = agent_id
      @udprn ||= udprn
      @buyer_id ||= buyer_id
    end

    def new_enquiries(enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, hash_str=nil, property_for='Sale', last_time=nil, is_premium=nil, buyer_id=nil, page_number=0, is_archived=nil, closed=nil, count=false, old_stats_flag=false)
      result = []
      events = Event::ENQUIRY_EVENTS.map { |e| Event::EVENTS[e] }
      ### Process filtered buyer_id only
      ### FIlter only the enquiries which are asked by the caller
      events = events.select{ |t| t == Event::EVENTS[enquiry_type.to_sym] } if enquiry_type

      ### Filter only the type_of_match which are asked by the caller
      query = filtered_agent_query agent_id: @agent_id, search_str: hash_str, last_time: last_time, is_premium: is_premium, buyer_id: buyer_id, type_of_match: type_of_match, is_archived: is_archived, closed: closed
      query = query.where(event: events) if enquiry_type
      query = query.where(stage: Event::EVENTS[qualifying_stage.to_sym]) if qualifying_stage
      query = query.where(rating: Event::EVENTS[rating.to_sym]) if rating
      
      if count && is_premium
        result = query.count
      elsif is_premium
        query = query.order('created_at DESC')
        total_rows = query.to_a
        result = self.class.process_enquiries_result(total_rows, @agent_id, is_premium, old_stats_flag)
      else
        query = query.order('created_at DESC')
        total_rows = query.limit(Event::PAGE_SIZE).offset(page_number.to_i*Event::PAGE_SIZE)
        result = self.class.process_enquiries_result(total_rows, @agent_id)
      end
      result
    end

  end
end
