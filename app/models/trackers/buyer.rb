class Trackers::Buyer

  def self.session
    Rails.configuration.cassandra_session
  end

  EVENTS = {
    impressions: 1,
    views: 2,
    property_tracking: 3,
    street_tracking: 4,
    locality_tracking: 5,
    would_view_if_green: 6,
    would_make_offer_if_green: 7,
    requested_message: 8,
    requested_callback: 9,
    requested_viewing: 10,
    deleted: 11,
    responded_to_email_request: 12,
    responded_to_callback_request: 13,
    responded_to_viewing_request: 14,
    qualifying_stage: 15,
    viewing_stage: 16,
    negotiating_stage: 17,
    offer_made_stage: 18,
    offer_accepted_stage: 19,
    closed_lost_stage: 20,
    closed_won_stage: 21,
    confidence_level: 22,
    visits: 23,
    contract_exchange_stage: 24,
    conveyance_stage: 25,
    completion_stage: 26,
  }

  TYPE_OF_MATCH = {
    perfect: 1,
    potential: 2,
    unlikely: 3
  }

  REVERSE_TYPE_OF_MATCH = TYPE_OF_MATCH.invert

  REVERSE_EVENTS = EVENTS.invert

  CONFIDENCE_ROWS = (1..5).to_a

  ENQUIRY_EVENTS = [
    :would_view_if_green,
    :would_make_offer_if_green,
    :requested_message,
    :requested_callback,
    :requested_viewing
  ]

  TRACKING_EVENTS = [
    :property_tracking,
    :locality_tracking,
    :street_tracking
  ]

  QUALIFYING_STAGE_EVENTS = [
    :qualifying_stage,
    :viewing_stage,
    :offer_made_stage,
    :negotiating_stage,
    :offer_accepted_stage,
    :conveyance_stage,
    :contract_exchange_stage,
    :completion_stage,
    :closed_won_stage,
    :closed_lost_stage
  ]

  def track(agent: agent_id, event: event_id, property: property_id, buyer: buyer_id)
    session = self.class.session
    session.execute("INSERT INTO buyer_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES ( #{agent_id}, #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
    session.execute("INSERT INTO property_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES (#{agent_id},  #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
    session.execute("INSERT INTO time_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES (#{agent_id},  #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
  end


  #### API Responses for tables

  def generic_execute_property_events_buyers(property_id, cql, status)
    # session = Trackers.session
    # future = session.execute(cql)
    result = []
    present_buyer_id = nil
    new_row = nil
    res = []
    future = [{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>1, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>2, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>4, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>8, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>9, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>10, "message"=>"2016-12-13", "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>11, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>14, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>18, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>19, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>20, "message"=>4,   "status_id"=>1, "type_of_match"=>1},
{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>123, "event"=>1, "message"=>nil, "status_id"=>1, "type_of_match"=>1}]
    future.each do |row|
      if row['buyer_id'] != present_buyer_id
        present_buyer_id = row['buyer_id']
        new_row = {}
        process_new_row(new_row, row, status)
        result.push(new_row)
      else
        process_new_row(new_row, row, status)
      end
    end
    p result
  end

  def self.mock_insert(table, *col_values)
    column_sql = <<-SQL
      SELECT *
      FROM system.schema_columns
      WHERE keyspace_name = 'simple' AND columnfamily_name = '#{table}';
    SQL
    session = self.class.session
  end

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ########## Property level enquiries ###########################

  def property_and_enquiry_details(property_id)
    url = "#{Rails.configuration.remote_es_url}/addresses/address/#{property_id}"
    response = Net::HTTP.get(URI.parse(url))
    details = response['_source']
    details = {}
    property_enquiry_details(property_id, details)
  end

  def property_enquiry_details(property_id, details)
    result = []
    res.each do |row|
      new_row = {}
      push_property_details(new_row, details)
      add_details_to_enquiry_row(new_row, details)
      result.push(new_row, details)
    end
    result
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_details(new_row, details)
    new_row[:address] = details['address']
    new_row[:image_url] = details['photos'][0]
    new_row[:status] = details['status']
    if details['status'] == 'Green'
      new_row[:asking_price] = details['asking_price']
      new_row[:offers_price] = details['offers_price']
      new_row[:fixed_price] = details['fixed_price']
    else
      new_row[:latest_valuation] = details['valuations'][0]
    end
    new_row[:property_type] = details['property_type']
    new_row[:beds] = details['beds']
    new_row[:baths] = details['baths']
    new_row[:recs] = details['receptions']
    new_row[:completed_status] = details['agent_status']
    new_row[:listed_since] = (Date.today - Date.parse(details['date_of_activation'])).to_i
    new_row[:agent_profile_image] = details['agent_profile_image']
    new_row[:advertised] = details['advertised']
  end

  def add_details_to_enquiry_row(new_row, details)
    session = self.class.session
    table = 'Simple.property_events_buyers_events'
    property_id = details['udprn']

    ### Extra keys to be added
    new_row['total_visits'] = generic_event_count(:visits, table, property_id, :single)
    new_row['total_enquiries'] = generic_event_count(ENQUIRY_EVENTS, table, property_id, :multiple)
    new_row['trackings'] = generic_event_count(TRACKING_EVENTS, table, property_id, :multiple)
    new_row['requested_viewing'] = generic_event_count(:requested_viewing, table, property_id, :single)
    new_row['offer_made'] = generic_event_count(:offer_made, table, property_id, :single)
    new_row['requested_message'] = generic_event_count(:requested_message, table, property_id, :single)
    new_row['requested_callback'] = generic_event_count(:requested_callback, table, property_id, :single)
    new_row['impressions'] = generic_event_count(:impressions, table, property_id, :single)
    new_row['deleted'] = generic_event_count(:deleted, table, property_id, :single)
  end

  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ###############################################################
  ########## Property level enquiries specific to a buyer #######

  def property_enquiry_details_buyer(agent_id)
    result = []
    events = ENQUIRY_EVENTS.map { |e| EVENTS[e] }.join(',')
    table = 'Simple.timestamped_property_events'
    received_cql = <<-SQL 
                      SELECT event, type_of_match, time_of_event, stored_time
                      FROM #{table} 
                      WHERE agent_id = #{agent_id}
                      AND event IN (#{events})
                      ORDER BY time_of_event DESC
                      LIMIT 20
                      ALLOW FILTERING
                    SQL
    
    session = self.class.session
    future = session.execute(event_sql)

    buyer_ids = []

    future.rows do |each_row|
      new_row = {}
      new_row['received'] = each_row['stored_time']
      new_row['type_of_enquiry'] = REVERSE_EVENTS[each_row['event']]
      new_row['type_of_match'] = REVERSE_TYPE_OF_MATCH[each_row['type_of_match']]
      property_id = new_row['property_id']
      push_property_details_row(new_row, property_id)
      add_details_to_enquiry_row_buyer(new_row, property_id, each_row, agent_id)
      buyer_ids.push(each_row['buyer_id'])
      result.push(new_row)
    end

    buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :email, :full_name, :mobile, :status, :chain_free]).order("position(id::text in '#{buyer_ids.join(',')}')")

    result.each_with_index do |each_row, index|
      each_row['buyer_status'] = buyers[index]['buyer_status']
      each_row['buyer_full_name'] = buyers[index]['buyer_full_name']
      each_row['buyer_email'] = buyers[index]['email']
      each_row['buyer_mobile'] = buyers[index]['mobile']
    end

    result
  end

  def push_property_details_row(new_row, property_id)
    url = "#{Rails.configuration.remote_es_url}/addresses/address/#{property_id}"
    response = Net::HTTP.get(URI.parse(url))
    details = response['_source']
    push_property_enquiry_details_buyer(property_id, details)
  end

  ### For every enquiry row, extract the info from details hash and merge it
  ### with new row
  def push_property_enquiry_details_buyer(new_row, details)
    new_row[:address] = details['address']
    new_row[:status] = details['status']
  end

  def add_details_to_enquiry_row_buyer(new_row, property_id, event_details, agent_id)
    new_row['type_of_match'] = event_details['type_of_match']
    
    #### Tracking property or not
    tracking_property_event = EVENTS[:property_tracking]
    buyer_id = event_details['buyer_id']
    tracking_prop_cql = <<-SQL
                        SELECT COUNT(*)
                        FROM simple.buyer_property_events
                        WHERE buyer_id = #{buyer_id}
                        AND property_id = #{property_id}
                        AND event = #{tracking_property_event}
                        SQL
    session = self.class.session
    future = session.execute(tracking_prop_cql)

    future.rows do |each_row|
      new_row[:property_tracking] = (each_row['count'] == 0 ? false : true)
    end

    table = 'simple.property_events_buyers_events'
    #### Views
    total_views = generic_event_count(EVENTS[:views], property_id, table, :single)
    buyer_views = generic_event_count_buyer(EVENTS[:views], property_id, table, buyer_id)
    new_row[:views] = buyer_views.to_i.to_s + '/' + total_views.to_i.to_s

    #### Enquiries
    total_enquiries = generic_event_count(ENQUIRY_EVENTS, table, property_id, :multiple)
    buyer_enquiries = generic_event_count(ENQUIRY_EVENTS, table, property_id, :multiple)
    new_row[:enquiries] = buyer_enquiries.to_i.to_s + '/' + total_enquiries.to_i.to_s

    #### Qualifying Stage
    qualifying_events = QUALIFYING_STAGE_EVENTS.map { |e| EVENTS[e] }.join(',')
    qualifying_cql = <<-SQL
                      SELECT event
                      FROM Simple.agents_buyer_events_timestamped
                      WHERE agent_id = #{agent_id} 
                      AND event IN (#{qualifying_events})
                      AND buyer_id = #{buyer_id}
                      ORDER BY buyer_id DESC, event DESC, time_of_event DESC
                      LIMIT 1;
                     SQL
    future = session.execute(qualifying_cql)

    future.rows do |each_row|
      new_row[:qualifying] = REVERSE_EVENTS[each_row['event']]
    end
    new_row
  end

  private

  def generic_event_count(event, property_id, table, type=:single)
    event_sql = nil
    if type == :single
      event_type = EVENTS[:event]
      event_sql = <<-SQL 
                    SELECT COUNT(*)
                    FROM #{table}
                    WHERE property_id = '#{property_id}'
                    AND event = #{event_type};
                  SQL
    else
      event_types = event.map { |e| EVENTS[e].to_s }.join(',')
      event_sql = <<-SQL
                    SELECT COUNT(*)
                    FROM #{table}
                    WHERE property_id = '#{property_id}'
                    AND event IN (#{event_types});
                  SQL
    end
    execute_count(event_sql)
  end

  def execute_count(event_sql)
    session = self.class.session
    future = session.execute(event_sql)
    count = nil
    future.rows do |each_row|
      count = each_row['count']
    end
    count
  end

  def generic_event_count_buyer(event, property_id, buyer_id, table, type=:single)
    event_sql = nil
    if type == :single
      event_type = EVENTS[:event]
      event_sql = <<-SQL
                    SELECT COUNT(*)
                    FROM #{table}
                    WHERE property_id='#{property_id}'
                    AND buyer_id = #{buyer_id}
                    AND event = #{event_type};
                  SQL
    else
      event_types = event.map { |e| EVENTS[e].to_s }.join(',')
      event_sql = <<-SQL
                    SELECT COUNT(*)
                    FROM #{table}
                    WHERE property_id='#{property_id}'
                    AND buyer_id = #{buyer_id}
                    AND event IN (#{event_types});
                  SQL
    end
    execute_count(event_sql)
  end

end

#CREATE KEYSPACE Simple WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };
=begin


#####################################################
#####################################################
#####################################################
#####################################################
DROP TABLE Simple.property_events_buyers_events;
DROP TABLE Simple.agents_buyer_events_timestamped;
DROP TABLE Simple.timestamped_property_events;
DROP TABLE Simple.buyer_property_events;

CREATE TABLE Simple.property_events_buyers_events (
    stored_time timestamp,
    date text,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((property_id), event, buyer_id, date)
);

CREATE TABLE Simple.agents_buyer_events_timestamped (
    stored_time timestamp,
    time_of_event timeuuid,
    agent_id int,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((agent_id), buyer_id, event, time_of_event)
);

SELECT * FROM Simple.timestamped_property_events WHERE agent_id = 23 AND buyer_id =  23 AND event= 3 ORDER BY buyer_id DESC , event DESC , time_of_event DESC LIMIT 1 ;

CREATE TABLE Simple.timestamped_property_events (
    stored_time timestamp,
    time_of_event timeuuid,
    agent_id int,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((agent_id), time_of_event, buyer_id)
);

CREATE TABLE Simple.buyer_property_events (
    stored_time timestamp,
    date text,
    buyer_id int,
    property_id text,
    status_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((buyer_id), property_id, event)
);


#####################################################
#####################################################

INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:01:01', '2016-07-11', '256070', 1, 1, 2, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:01:02', '2016-07-11', '256070', 1, 1, 3, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:02:03', '2016-07-11', '256070', 1, 1, 15, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:03:04', '2016-07-11', '256070', 1, 1, 16, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:04:05', '2016-07-11', '256070', 1, 1, 17, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:04:06', '2016-07-11', '256070', 1, 1, 18, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:05:07', '2016-07-11', '256070', 1, 1, 19, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:06:08', '2016-07-11', '256070', 1, 1, 23, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:07:09', '2016-07-11', '256070', 1, 1, 8, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:08:10', '2016-07-11', '256070', 1, 1, 9, NULL, 1);
INSERT INTO Simple.property_events_buyers_events (stored_time, date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ('2016-07-11 01:09:11', '2016-07-11', '256070', 1, 1, 10, NULL, 1);


INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:01:01', now(), 4532, '256070', 1, 1,  2, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:02:01', now(), 4532, '256070', 1, 1,  3, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:03:01', now(), 4532, '256070', 1, 1,  15, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:04:01', now(), 4532, '256070', 1, 1, 16, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:05:01', now(), 4532, '256070', 1, 1, 17, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:06:01', now(), 4532, '256070', 1, 1, 18, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:07:01', now(), 4532, '256070', 1, 1, 19, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:08:01', now(), 4532, '256070', 1, 1, 23, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:09:01', now(), 4532, '256070', 1, 1,  8, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:10:01', now(), 4532, '256070', 1, 1,  9, NULL, 1);
INSERT INTO Simple.agents_buyer_events_timestamped (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:11:01', now(), 4532, '256070', 1, 1, 10, NULL, 1);


INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:01:01', now(), 4532, '256070', 1, 1,  2, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:02:01', now(), 4532, '256070', 1, 1,  3, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:03:01', now(), 4532, '256070', 1, 1,  15, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:04:01', now(), 4532, '256070', 1, 1, 16, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:05:01', now(), 4532, '256070', 1, 1, 17, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:06:01', now(), 4532, '256070', 1, 1, 18, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:07:01', now(), 4532, '256070', 1, 1, 19, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:08:01', now(), 4532, '256070', 1, 1, 23, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:09:01', now(), 4532, '256070', 1, 1,  8, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:10:01', now(), 4532, '256070', 1, 1,  9, NULL, 1);
INSERT INTO Simple.timestamped_property_events (stored_time, time_of_event, agent_id, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11 01:11:01', now(), 4532, '256070', 1, 1, 10, NULL, 1);


INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:01:01', '2016-07-11', 1, '256070', 1, 2 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:02:01', '2016-07-11', 1, '256070', 1, 3 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:03:01', '2016-07-11', 1, '256070', 1, 15 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:04:01', '2016-07-11', 1, '256070', 1, 16 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:05:01', '2016-07-11', 1, '256070', 1, 17 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:06:01', '2016-07-11', 1, '256070', 1, 18 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:07:01', '2016-07-11', 1, '256070', 1, 19 , NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:08:01', '2016-07-11', 1, '256070', 1, 23, NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:09:01', '2016-07-11', 1, '256070', 1, 8, NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:10:01', '2016-07-11', 1, '256070', 1, 9, NULL, 1 );
INSERT INTO Simple.buyer_property_events (stored_time, date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11 01:11:01', '2016-07-11', 1, '256070', 1, 10, NULL, 1 );



=end