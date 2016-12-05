require 'cassandra'

class EventsController < ApplicationController
  include EventsHelper

  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '45326', "event" : "property_tracking", "message" : null, "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  
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
    Rails.logger.info("PROGRESS")
    type_of_match = Trackers::Buyer::TYPE_OF_MATCH[params[:type_of_match].downcase.to_sym]
    # type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    property_id = params[:udprn]
    Rails.logger.info("PROGRESS 2")
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
  def agent_enquiries_by_property
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Trackers::Buyer.new.all_property_enquiry_details(params[:agent_id], params[:hash_str], params[:hash_type])
    elsif !params[:hash_str].nil?
      response = Trackers::Buyer.new.all_property_enquiry_details(nil, params[:hash_str], params[:hash_type])
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      buyer = Trackers::Buyer.new
      response = agents.map { |e| buyer.all_property_enquiry_details(e.id, nil, nil) }.flatten
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/enquiries/new/1234'
  def agent_new_enquiries
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Trackers::Buyer.new.property_enquiry_details_buyer(params[:agent_id].to_i)
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
      response = agents.map { |e| buyer.property_enquiry_details_buyer(e) }.flatten.sort_by{ |t| t['time_of_event'] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      buyer = Trackers::Buyer.new
      response = agents.map { |e| buyer.property_enquiry_details_buyer(e) }.flatten.sort_by{ |t| t['time_of_event'] }.reverse
    elsif !params[:agent_group_id].nil?
      ### TODO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end


  #### For agents the quotes page has to be shown in which all his recent or the new properties in the area
  #### Will be published
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234'
  def recent_properties_for_quotes
    response = []
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_quotes
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
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_quotes }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_quotes }.flatten.sort_by{ |t| t[:deadline] }.reverse
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
    if !params[:agent_company_id].nil?
      ### TODO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i).recent_properties_for_claim
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
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_claim }.flatten.sort_by{ |t| t[:deadline] }.reverse
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      response = agents.map { |e| Agents::Branches::AssignedAgent.find(e).recent_properties_for_claim }.flatten.sort_by{ |t| t[:deadline] }.reverse
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

end
