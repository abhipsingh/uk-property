require 'cassandra'

class EventsController < ApplicationController


  ### List of params
  ### :udprn, :event, :message, :type_of_match, :buyer_id, :agent_id
  ### 
  def process_event
    session = Rails.configuration.cassandra_session
    date = Date.today.to_s
    time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[params[:property_status_type]]
    buyer_id = params[:buyer_id]
    event = Trackers::Buyer::EVENTS.with_indifferent_access[params[:event]]
    message = params[:message]
    # type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    property_id = params[:udprn]
    agent_id = params[:agent_id]
    message = 'NULL' if message.nil?
    cqls = [
            "INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message) VALUES ('#{time}', '#{date}', '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, NULL);",
            "INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, NULL);",
            "INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id},  #{event}, NULL);",
            "INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message) VALUES ( '#{time}', '#{date}', #{buyer_id}, '#{property_id}', #{property_status_type}, #{event}, NULL);"
          ]

    Rails.logger.info(cqls)

    cqls.map { |each_cql| session.execute(each_cql)  }

    render json: { 'message' => 'Successfully processed' }, status: 200
  end

end
