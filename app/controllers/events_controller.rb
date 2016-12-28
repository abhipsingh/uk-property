require 'cassandra'

class EventsController < ApplicationController
  include EventsHelper

  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "property_tracking", "message" : null, "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of saved search pings
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "save_search_hash", "message" : "\{\"search_hash\" : \{ \"min_beds\" : 2, \"max_beds\" : 3, \"min_baths\" : 1, \"max_baths\" : 2, \"hash_str\" : \"HEREFORD_City Centre_Loder Drive\", \"hash_type\" = \"Text\"  \} \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
  ### An example of property getting sold
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10966183', "event" : "sold", "message" : "\{\"final_price\" : 300000, \"exchange_of_contracts\" : \"2016-11-23\" \}" , "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  def process_event
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[params[:property_status_type]]
    buyer_id = params[:buyer_id]
    event = Trackers::Buyer::EVENTS.with_indifferent_access[params[:event]]

    #### Search hash of a message
    message = params[:message]
    type_of_match = Trackers::Buyer::TYPE_OF_MATCH[params[:type_of_match].downcase.to_sym]
    # type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    property_id = params[:udprn]
    agent_id = params[:agent_id]
    message = 'NULL' if message.nil?
    response = insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)

    Rails.logger.info("COMPLETED")
    render json: { 'message' => 'Successfully processed the request', response: response }, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise

  def buyer_enquiries
  end


  #### For agents implement filter of agents group wise, company wise, branch wise, location wise,
  #### and agent_id wise. The agent employee is the last missing layer.
  ####  curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234'
  #### Three types of filters i) Verification status and property status type
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=true&property_status_type=Green'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=false&property_status_type=Red'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/property/1234?verification_status=true&property_status_type=Green'

  def agent_enquiries_by_property
    property_status_type = params[:property_status_type]
    verification_status = params[:verification_status]
    ads = params[:ads]
    search_str = params[:search_str]
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Trackers::Buyer.new.search_latest_enquiries(params[:agent_id].to_i, property_status_type, verification_status, ads, search_str)
    elsif !params[:hash_str].nil?
      response = Trackers::Buyer.new.property_and_enquiry_details(property_id)
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      buyer = Trackers::Buyer.new
      response = []
      agents.each do |agent|
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent.id, status: Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']).pluck(:property_id)
        property_ids.each{ |t| response.push(buyer.property_and_enquiry_details(agent.id, t, property_status_type, verification_status, ads)) }.compact
      end 
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise. 
  #### New Changes and additions
  #### The leads can be filtered as well. Four different kind of filters apply. 
  #### i) Type of buyer enquiry
  #### ii) Type of match
  #### iii) Qualifying stage
  #### iv) Rating
  #### v) By Buyer's funding type, chain free, biggest problems etc
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/new/1234'
  def agent_new_enquiries
    enquiry_type = params[:enquiry_type]
    type_of_match = params[:type_of_match]
    qualifying_stage = params[:qualifying_stage]
    rating = params[:rating]
    buyer_status = params[:buyer_status]
    buyer_funding = params[:buyer_funding]
    buyer_biggest_problem = params[:buyer_biggest_problem]
    buyer_chain_free = params[:buyer_chain_free]
    search_str = params[:search_str]
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      Rails.logger.info("#{params[:agent_id]}__#{search_str}")
      response = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i, enquiry_type, type_of_match, qualifying_stage, rating, buyer_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str)
    elsif !params[:hash_str].nil?
      search_params = { limit: 10000, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      if status.to_i == 200
        agents = body.map { |e| e['agent_id'] }.uniq rescue []
      end
      buyer = Trackers::Buyer.new
      response = agents.map { |e| buyer.property_enquiry_details_buyer(e, enquiry_type, type_of_match, qualifying_stage, rating, buyer_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str) }.flatten.sort_by{ |t| t['time_of_event'] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      buyer = Trackers::Buyer.new
      response = agents.map { |e| buyer.property_enquiry_details_buyer(e, enquiry_type, type_of_match, qualifying_stage, rating, buyer_status, buyer_funding, buyer_biggest_problem, buyer_chain_free, search_str) }.flatten.sort_by{ |t| t['time_of_event'] }.reverse
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end


  #### For agents the quotes page has to be shown in which all his recent or the new properties in the area
  #### Will be published
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234'
  #### For applying filters i) payment_terms
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&payment_terms=Pay%20upfront'
  #### ii) services_required
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&services_required=Ala%20Carte'
  #### ii) quote_status
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&quote_status=Won'
  def recent_properties_for_quotes
    
    services_required = params[:services_required]
    quote_status = params[:quote_status]
    payment_terms = params[:payment_terms]
    search_str = params[:search_str]
    
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_quotes(payment_terms, services_required, quote_status, search_str)
    elsif !params[:hash_str].nil?
      search_params = { limit: 10000, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      if status.to_i == 200
        agents = body.map { |e| e['agent_id'] }.uniq rescue []
      end
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_quotes(payment_terms, services_required, quote_status, search_str) }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_quotes(payment_terms, services_required, quote_status, search_str) }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_group_id].nil?
      ### TO DO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end


  #### For agents the leads page has to be shown in which the recent properties have been claimed
  #### Those properties have just been claimed recently in the area
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/claims?agent_id=1234'
  def recent_properties_for_claim
    response = []
    status = params[:status]
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_claim(status)
    elsif !params[:hash_str].nil?
      search_params = { limit: 100, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      if status.to_i == 200
        agents = body.map { |e| e['agent_id'] }.uniq rescue []
      end
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_claim(status) }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_claim(status) }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### When an agent wants to see the property specific statistics(trackings,
  #### views, etc), this API is called. All enquiries regarding properties he is associated to are returned.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/properties?agent_id=1234'
  def property_enquiries
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i)
    elsif !params[:hash_str].nil?
      search_params = { limit: 100, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      if status.to_i == 200
        agents = body.map { |e| e['agent_id'] }.uniq rescue []
      end
      response = agents.map { |e| Trackers::Buyer.new.property_enquiry_details_buyer(e) }.flatten.sort_by{ |t| t['status_last_updated'] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      response = agents.map { |e| Trackers::Buyer.new.property_enquiry_details_buyer(e) }.flatten.sort_by{ |t| t['status_last_updated'] }.reverse
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end


  #### On demand quicklink for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties?agent_id=1234'
  def detailed_properties
    response = []
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: params[:agent_id], status: status).pluck(:property_id)
      response = property_ids.uniq.map { |e| PropertyDetails.details(e) }
    elsif !params[:hash_str].nil?
      search_params = { limit: 100, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      agent_ids = []
      
      if status.to_i == 200
        agent_ids = body.map { |e| e['agent_id'] }.uniq rescue []
      end

      ### Iterate over agent_ids
      agent_ids.each do |agent_id|
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, status: status).pluck(:property_id)
        response |= property_ids.uniq.map { |e| PropertyDetails.details(e) }
      end

    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      ### Iterate over agent_ids
      agent_ids.each do |agent_id|
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, status: status).pluck(:property_id)
        response |= property_ids.uniq.map { |e| PropertyDetails.details(e) }
      end

    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### On demand detailed properties for all the properties of agents, or group or branch or company
  #### To get list of properties for the concerned agent
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/quicklinks/properties?agent_id=1234'
  def quicklinks
    response = []
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: params[:agent_id], status: status).pluck(:property_id)
      response = property_ids.uniq
    elsif !params[:hash_str].nil?
      search_params = { limit: 100, fields: 'agent_id' }
      search_params[:hash_str] = params[:hash_str]
      search_params[:hash_type] = params[:hash_type]
      api = PropertyDetailsRepo.new(filtered_params: search_params)
      api.apply_filters
      body, status = api.fetch_data_from_es
      agent_ids = []
      
      if status.to_i == 200
        agent_ids = body.map { |e| e['agent_id'] }.uniq rescue []
      end

      ### Iterate over agent_ids
      agent_ids.each do |agent_id|
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, status: status).pluck(:property_id)
        response |= property_ids.uniq
      end

    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      ### Iterate over agent_ids
      agent_ids.each do |agent_id|
        property_ids = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, status: status).pluck(:property_id)
        response |= property_ids.uniq
      end

    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### When an agent click the claim to a property, the agent gets a chance to visit
  #### the picture. The claim needs to be frozen and the property is no longer available
  #### for claiming.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/property/claim/4745413' -d { "agent_id" : 1235 }
  def claim_property
    lead = Agents::Branches::AssignedAgents::Lead.where(property_id: params[:udprn].to_i, agent_id: nil).last
    if lead
      lead.agent_id = params[:agent_id]
      lead.save
      render json: { message: 'You have claimed this property Successfully. Now survey this property within 30 days' }, status: 200
    else
      render json: { message: 'Sorry, this property has already been claimed' }, status: 200
    end
  end

end
