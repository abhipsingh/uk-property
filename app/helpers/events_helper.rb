module EventsHelper

  def insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
    session = Rails.configuration.cassandra_session
    date = Date.today.to_s
    month = Date.today.month
    time = Time.now.strftime("%Y-%m-%d %H:%M:%S").to_s
    cqls = [
            "INSERT INTO Simple.property_events_buyers_events (stored_time, time_of_event, date, property_id, status_id, buyer_id, event, message, type_of_match, month) VALUES ('#{time}', now(), '#{date}', '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, '#{message}', #{type_of_match}, #{month});",
            "INSERT INTO Simple.agents_buyer_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id}, #{event}, '#{message}', #{type_of_match});",
            "INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '#{time}', now(), #{agent_id}, '#{property_id}', #{property_status_type}, #{buyer_id},  #{event}, '#{message}', #{type_of_match});",
            "INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match, month) VALUES ( '#{time}', '#{date}', #{buyer_id}, '#{property_id}', #{property_status_type}, #{event}, '#{message}', #{type_of_match}, #{month});"
          ]

    cqls.map { |e| Rails.logger.info(e)  }

    cqls.map { |each_cql| session.execute(each_cql)  }

    response = {}

    if event == Trackers::Buyer::EVENTS[:sold]
      host = Rails.configuration.remote_es_host
      client = Elasticsearch::Client.new host: host
      response = client.update index: 'addresses', type: 'address', id: property_id.to_s,
                        body: { doc: { property_status_type: 'Red', vendor_id: buyer_id } }
    end
    response
  end

end