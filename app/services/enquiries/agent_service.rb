module Enquiries
  class AgentService
    include EnquiryInfoHelper

    attr_accessor :agent_id, :udprn, :buyer_id

    def initialize(agent_id: agent, udprn: udprn=nil, buyer_id: buyer=nil)
      @agent_id = agent_id
      @udprn ||= udprn
      @buyer_id ||= buyer_id
    end

    def new_enquiries(enquiry_type=nil, type_of_match=nil, qualifying_stage=nil, rating=nil, hash_str=nil, property_for='Sale', last_time=nil, is_premium=nil, buyer_id=nil, page_number=1, is_archived=nil, closed=nil, count=false, old_stats_flag=false)
      result = []
      count = nil
      events = Event::ENQUIRY_EVENTS.map { |e| Event::EVENTS[e] }
      ### Process filtered buyer_id only
      ### FIlter only the enquiries which are asked by the caller
      events = events.select{ |t| t == Event::EVENTS[enquiry_type.to_sym] } if enquiry_type

      ### Filter only the type_of_match which are asked by the caller
      query = filtered_agent_query agent_id: @agent_id, search_str: hash_str, last_time: last_time, is_premium: is_premium, buyer_id: buyer_id, type_of_match: type_of_match, is_archived: is_archived, closed: closed
      query = query.where(event: events) if enquiry_type
      query = query.where(stage: Event::EVENTS[qualifying_stage.to_sym]) if qualifying_stage
      query = query.where(rating: Event::EVENTS[rating.to_sym]) if rating
 
      if is_premium
        query = query.order('created_at DESC')
        total_rows = query.to_a
        count = total_rows.count
        result = self.class.process_enquiries_result(total_rows, @agent_id, is_premium, old_stats_flag)
      else
        query = query.order('created_at DESC')
        count = query.count
        page_number ||= 1
        page_number = page_number.to_i
        page_number -= 1
        total_rows = query.limit(Event::PAGE_SIZE).offset(page_number.to_i*Event::PAGE_SIZE)
        result = self.class.process_enquiries_result(total_rows, @agent_id)
      end

      return result, count
    end

    def self.merge_property_details(details, new_row)
      new_row[:percent_completed] = ::PropertyService.new(details[:_source][:udprn]).compute_percent_completed({}, details[:_source] )
      new_row[:percent_completed] ||= nil
      new_row[:verification_status] = (new_row[:percent_completed].to_i == 100)
      new_row[:details_completed] = (new_row[:percent_completed].to_i == 100)
      new_row[:address] = PropertyDetails.address(details[:_source])
      new_row[:pictures] = details[:_source][:pictures]
      new_row[:pictures] = [] if details[:_source][:pictures].nil?
      image_url ||= "https://s3.ap-south-1.amazonaws.com/google-street-view-prophety/#{details[:_source][:udprn]}/fov_120_#{details[:_source][:udprn]}.jpg"
      new_row[:street_view_image_url] = image_url
      new_row[:status_last_updated] = details[:_source][:status_last_updated]
      new_row[:status_last_updated] = Time.parse(new_row[:status_last_updated]).strftime("%Y-%m-%dT%H:%M:%SZ") if new_row[:status_last_updated] 
    end

    #### Push event based additional details to each property details
    ### Trackers::Buyer.new.push_events_details(PropertyDetails.details(10966139))
    def self.push_events_details(details, is_premium=false, old_stats_flag=false)
      new_row = {}
      merge_property_details(details, new_row)
      add_enquiry_stats(new_row, details['_source'], is_premium, old_stats_flag)
      vendor_id = details[:_source][:vendor_id]
  
      lead = Agents::Branches::AssignedAgents::Lead.where(property_id: details[:_source][:udprn].to_i, vendor_id: vendor_id.to_i).last
      if lead
        new_row[:lead_expiry_time] = (lead.created_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT).strftime("%Y-%m-%dT%H:%M:%SZ")
      else
        new_row[:lead_expiry_time] = nil
      end
  
      details['_source'].merge!(new_row)
      details['_source']
    end

  end
end
