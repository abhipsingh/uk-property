require 'cassandra'

class EventsController < ApplicationController


  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '45326', "event" : "property_tracking", "message" : null, "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'
  def process_event
    session = Rails.configuration.cassandra_session
    date = Date.today.to_s
    time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
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
    cqls = [
            "INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('#{time}', '#{date}', '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, NULL, #{type_of_match});",
            "INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, NULL, #{type_of_match});",
            "INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id},  #{event}, NULL, #{type_of_match});",
            "INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '#{time}', '#{date}', #{buyer_id}, '#{property_id}', #{property_status_type}, #{event}, NULL, #{type_of_match});"
          ]

    Rails.logger.info(cqls)

    cqls.map { |each_cql| session.execute(each_cql)  }

    render json: { 'message' => 'Successfully processed the request' }, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise

  def buyer_enquiries
  end


  #### For agents implement filter of agents group wise, company wise, branch wise, location wise,
  #### and agent_id wise. The agent employee is the last missing layer.

  def agent_enquiries_by_property
    response = []
    if !params[:agent_company_id].nil?
      ### TO DO FOR COMPANY
    elsif !params[:agent_id].nil?
      response = Trackers::Buyer.new.all_property_enquiry_details(params[:agent_id], params[:hash_str], params[:hash_type])
    elsif !params[:hash_str].nil?
      response = Trackers::Buyer.new.all_property_enquiry_details(nil, params[:hash_str], params[:hash_type])
    elsif !params[:agent_branch_id].nil?
      agents = Agents::Branches::AssignedAgent.where(branch_id: params[:agent_branch_id].to_i).select(:id)
      buyer = Trackers::Buyer.new
      response = agents.map { |e| buyer.all_property_enquiry_details(e.id, nil, nil) }.flatten
    elsif !params[:agent_group_id].nil?
      ### TO DO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  #### For agents implement filter of agents group wise, company wise, branch, location wise,
  #### and agent_id wise

  def agent_new_enquiries
    response = []
    if !params[:agent_company_id].nil?
      ### TO DO FOR COMPANY
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
      ### TO DO FOR AGENTS GROUP AS WELL
    end
    render json: response, status: 200
  end

  def property_enquiries

  end

end
