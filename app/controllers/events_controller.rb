require 'cassandra'

class EventsController < ApplicationController


  ### List of params
  ### :property_id, :event, :message, :type_of_match, :buyer_id
  def process_event
    Trackers::Buyer

    session = Rails.configuration.cassandra_session
    date = Date.today.to_s
    time = Time.now.to_s
    status_id = Trackers::Buyer::STATUS_MAP.with_indifferent_access[params[:status]]
    buyer_id = params[:buyer_id]
    event = Trackers::Buyer::EVENTS.with_indifferent_access[params[:event]]
    message = params[:message]
    type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]
    udprn = params[:udprn]
    message = 'NULL' if message.nil?
    cqls = [
            "INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{date}', '#{udprn}', #{status_id}, #{buyer_id}, #{event}, #{message}, #{type_of_match} );",
            "INSERT INTO Simple.property_events_buyers_dated (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{date}', '#{udprn}', #{status_id}, #{buyer_id}, #{event}, #{message}, #{type_of_match}  );",
            "INSERT INTO Simple.property_events_buyers_non_dated (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES (  '#{date}', '#{udprn}', #{status_id}, #{buyer_id}, #{event}, #{message}, #{type_of_match}  );",
            "INSERT INTO Simple.buyer_events (date, buyer_id, status_id, property_id, event, message, type_of_match) VALUES (  '#{date}', #{buyer_id}, #{status_id}, '#{udprn}', #{event}, #{message}, #{type_of_match}  );",
            "INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, status_id, property_id, event, message, type_of_match) VALUES ( '#{date}', #{buyer_id}, #{status_id}, '#{udprn}', #{event}, #{message}, #{type_of_match} );"
          ]
    cqls.map { |each_cql| session.execute(each_cql)  }

    render json: { 'message' => 'Successfully processed' }, status: 200
  end

end
