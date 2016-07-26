require 'cassandra'
module Trackers

  def self.session
    cluster = Cassandra.cluster
    keyspace = 'simple'
    cluster.connect(keyspace)
  end

  class Buyer
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
      confidence_level: 20
    }

    TYPE_OF_MATCH = {
      perfect: 1,
      potential: 2,
      unlikely: 3
    }

    STATUS_MAP = {
      'Green' => 1,
      'Amber' => 2,
      'Red'   => 3
    }

    REVERSE_STATUS_MAP = STATUS_MAP.invert

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

    def track(event: event_id, property: property_id, buyer: buyer_id)
      session = Trackers.session
      session.execute("INSERT INTO buyer_events_buyer (buyer_id, property_id, event, time, status_id) VALUES (#{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
      session.execute("INSERT INTO property_events_buyer (buyer_id, property_id, event, time, status_id) VALUES (#{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
      session.execute("INSERT INTO time_events_buyer (buyer_id, property_id, event, time, status_id) VALUES (#{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
    end

  end

  class Agent

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
      confidence_level: 20
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

    def track(agent: agent_id, event: event_id, property: property_id, buyer: buyer_id)
      session = Trackers.session
      session.execute("INSERT INTO buyer_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES ( #{agent_id}, #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
      session.execute("INSERT INTO property_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES (#{agent_id},  #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
      session.execute("INSERT INTO time_events_agents (agent_id, buyer_id, property_id, event_id, time) VALUES (#{agent_id},  #{buyer_id}, #{property_id}, #{EVENTS[event_id]}, #{Date.today.to_s} )")
    end


    #### API Responses for tables


    #### Get enquiry date wise

    #### Columns [:responded_to_email_request, :responded_to_callback_request, :responded_to_viewing_request, :deleted, 
    ####          :qualifying, :viewing, :negotiating, :offer_made, :offer_accepted, :closed_lost, :closed_won, :confidence_level]

    def buyer_enquiries_for_agents_green_properties(property_id)
      cql = "SELECT * FROM Simple.property_events_buyers WHERE property_id = '#{property_id}';"
      generic_execute_property_events_buyers(property_id, cql, :green)
    end

    def buyer_enquiries_for_agents_non_green_properties(property_id)
      cql = "SELECT * FROM Simple.property_events_buyers WHERE property_id = '#{property_id}';"
      generic_execute_property_events_buyers(property_id, cql, :non_green)
    end

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

    def process_new_row(new_row, row, status)
      if status == :green
        process_new_row_green(new_row, row)
      else
        process_new_row_non_green(new_row, row)
      end
    end

    def process_new_row_non_green(new_row, row)
      (EVENTS[:would_view_if_green]..EVENTS[:closed_won_stage]).each do |event|
        process_count_event(REVERSE_EVENTS[event], new_row, row)
      end
      new_row[REVERSE_EVENTS[row['event']]] += 1
      set_count_confidence_level(new_row, row)
    end

    def process_new_row_green(new_row, row)
      process_boolean_event(:responded_to_email_request, new_row, row)
      process_boolean_event(:responded_to_callback_request, new_row, row)
      process_boolean_event(:responded_to_viewing_request, new_row, row)
      process_boolean_event(:deleted, new_row, row)
      process_boolean_event(:qualifying_stage, new_row, row)
      process_boolean_event(:viewing_stage, new_row, row)
      process_boolean_event(:negotiating_stage, new_row, row)
      process_boolean_event(:offer_made_stage, new_row, row)
      process_boolean_event(:offer_accepted_stage, new_row, row)
      process_boolean_event(:closed_lost_stage, new_row, row)
      process_boolean_event(:closed_won_stage, new_row, row)
      set_qualifying_stage_value(new_row)
      set_confidence_level(new_row, row)
    end

    def process_count_event(event, new_row, row)
      if new_row[REVERSE_EVENTS[row['event']]] == nil
        new_row[REVERSE_EVENTS[row['event']]] = 0
      end
    end

    def process_boolean_event(event, new_row, row)
      if new_row[event] != true
        new_row[event] = (REVERSE_EVENTS[row['event']] == event) ? true : false
      end
    end

    def set_qualifying_stage_value(new_row)
      max_true = (EVENTS[:qualifying_stage]..EVENTS[:offer_accepted_stage]).to_a.select{|t| new_row[REVERSE_EVENTS[t]] == true }.max
      (EVENTS[:qualifying_stage]..(max_true - 1)).to_a.map { |e| new_row[REVERSE_EVENTS[e]] = false } if max_true
    end

    def set_confidence_level(new_row, row)
      if REVERSE_EVENTS[row['event']] == :confidence_level
        new_row["confidence_#{row['message']}"] = true
        (CONFIDENCE_ROWS - [row['message']]).map { |e| new_row["confidence_#{e}"] = false }
      end
    end

    def set_count_confidence_level(new_row, row)
      if REVERSE_EVENTS[row['event']] == :confidence_level
        if new_row["confidence_#{row['message']}"].nil?
          new_row["confidence_#{row['message']}"] = 1
        else
          new_row["confidence_#{row['message']}"] += 1
        end
      end
    end

    ###############################################################
    ###############################################################
    ###############################################################
    ### Property level enquiries ##################################

    def property_and_enquiry_details(property_id)
      # url = "http://ec2-52-38-219-110.us-west-2.compute.amazonaws.com/addresses/address/#{property_id}"
      # response = Net::HTTP.get(URI.parse(url))
      # details = response['_source']
      details = {}
      property_enquiry_details(property_id, details)

    end

    def property_enquiry_details(property_id, details)
      cql = "SELECT * FROM Simple.property_events_buyers WHERE property_id = #{property_id}"
      # session = Trackers.session

      # future = session.execute(cql) # fully asynchronous api
      result = []
      present_buyer_id = nil
      present_date = nil
      new_row = nil

      perfect_matches = 0
      potential_matches = 0

      res =  [{"property_id"=>"12", "date"=>"2016-07-11", "buyer_id"=>12, "event"=>1, "message"=>nil, "status_id"=>1, "type_of_match"=>1},
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

      res.each do |row|
        if row['date'] != present_date || row['buyer_id'] != present_buyer_id
          present_buyer_id = row['buyer_id']
          present_date = row['date']

          new_row ||= {}
          new_row[:views] = new_row[:buyer_views].to_s+'/'+new_row[:total_views].to_s
          new_row[:enquiries] = new_row[:buyer_enquiries].to_s+'/'+new_row[:total_enquiries].to_s

          perfect_matches += 1 if REVERSE_TYPE_OF_MATCH[row['type_of_match']] == :perfect
          potential_matches += 1 if REVERSE_TYPE_OF_MATCH[row['type_of_match']] == :potential

          result.push(new_row)
          new_row = {}
        end
        if true # if details['status'] == 'GREEN'
          process_row_enquiry_details_green(new_row, row, details)
        else
          process_row_enquiry_details_non_green(new_row, row, details)
        end
      end

      result.each_with_index do |each_res, index|
        result[index][:perfect] = perfect_matches
        result[index][:potential_matches] = potential_matches
      end

    end

    def process_row_enquiry_details_green(new_row, row, details)
      if new_row.empty?
        new_row[:date] = row['date']
        new_row[:status] = details['status']
        new_row[:photo_url] = details['photo_url']
        # buyer = PropertyUser.find(row['buyer_id'])
        # new_row[:contact_number] = buyer.contact_number rescue nil
        new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[row['type_of_match']]
        
        new_row[:total_views] = 0 if new_row[:total_views].nil?
        new_row[:total_enquiries] = 0 if new_row[:total_enquiries].nil?
        ### new_row[:type_of_buyer] =  Nowhere being stored
        ### new_row[:chain] =  Nowhere being stored

        cql = "SELECT event FROM  Simple.buyer_events_non_dated WHERE buyer_id = #{row['buyer_id']} "
        session = Trackers.session
        future = session.execute(cql) 
        future.rows do |buyer_row|
          new_row[:total_views] += 1 if REVERSE_EVENTS[buyer_row['event']] == :views
          new_row[:total_enquiries] += 1 if  ENQUIRY_EVENTS.include?(REVERSE_EVENTS[buyer_row['event']])
        end
        new_row[:replied] = false
        new_row[:type_of_enquiry] = []

      end
      new_row[:buyer_views] = 0 if new_row[:buyer_views].nil?
      new_row[:buyer_views] += 1 if REVERSE_EVENTS[row['event']] == :views

      new_row[:buyer_enquiries] = 0 if new_row[:enquiries].nil?
      new_row[:buyer_enquiries] += 1 if ENQUIRY_EVENTS.include?(REVERSE_EVENTS[row['event']])
      new_row[:property_tracking] = false if new_row[:property_tracking].nil?
      new_row[:property_tracking] = true if REVERSE_EVENTS[row['event']] == :property_tracking

      new_row[:enquiry_status] = REVERSE_EVENTS[row['event']] if row['event'] <= EVENTS[:closed_won_stage] || row['event'] >= EVENTS[:qualifying_stage]
      new_row[:confidence_level] = row['message'] if REVERSE_EVENTS[row['event']] == :confidence_level

      if [:responded_to_email_request, :responded_to_callback_request, :responded_to_viewing_request].include?(REVERSE_EVENTS[row['event']])
        new_row[:replied] = true
      end

      events = [:property_tracking, :requested_callback, :requested_message, :requested_viewing, :would_view_if_green, :would_make_offer_if_green]
      if events.include?(REVERSE_EVENTS[row['event']])
        new_row[:type_of_enquiry].push(REVERSE_EVENTS[row['event']])
      end

    end

    def process_row_enquiry_details_non_green(new_row, row, details)
      if new_row.empty?
        new_row[:date] = row['date']
        new_row[:status] = details['status']
        new_row[:photo_url] = details['photo_url']
        # buyer = PropertyUser.find(row['buyer_id'])
        # new_row[:contact_number] = buyer.contact_number rescue nil
        new_row[:type_of_match] = REVERSE_TYPE_OF_MATCH[row['type_of_match']]
        
        new_row[:total_views] ||= 0
        new_row[:total_enquiries] ||= 0
        new_row[:total_tracking] ||= 0
        new_row[:total_enquiries] ||= 0
        new_row[:total_would_view_if_green] ||= 0
        new_row[:total_requested_callback] ||= 0
        new_row[:total_would_make_offer_if_green] ||= 0
        new_row[:total_requested_message] ||= 0
        ### new_row[:type_of_buyer] =  Nowhere being stored
        ### new_row[:chain] =  Nowhere being stored

        cql = "SELECT event FROM Simple.buyer_events_non_dated WHERE buyer_id = #{row['buyer_id']} "
        session = Trackers.session
        future = session.execute(cql) 
        new_row[:total_views] = new_row[:total_enquiries] = new_row[:total_tracking] = new_row[:total_would_view_if_green] = new_row[:total_would_make_offer_if_green] = 0
        future.rows do |buyer_row|
          new_row[:total_views] += 1 if REVERSE_EVENTS[buyer_row['event']] == :views
          new_row[:total_enquiries] += 1 if  ENQUIRY_EVENTS.include?(REVERSE_EVENTS[buyer_row['event']])
          new_row[:total_tracking] += 1 if REVERSE_EVENTS[buyer_row['event']] == :property_tracking
          new_row[:total_would_view_if_green] += 1 if REVERSE_EVENTS[buyer_row['event']] == :would_view_if_green
          new_row[:total_would_make_offer_if_green] += 1 if REVERSE_EVENTS[buyer_row['event']] == :would_make_offer_if_green
          new_row[:total_requested_callback] += 1 if REVERSE_EVENTS[buyer_row['event']] == :requested_callback
          new_row[:total_requested_message] += 1 if REVERSE_EVENTS[buyer_row['event']] == :requested_message
        end
        new_row[:replied] = false
        new_row[:type_of_enquiry] = []
        new_row[:perfect] = 0
        new_row[:potential] = 0

      end
      new_row[:buyer_views] = 0 if new_row[:buyer_views].nil?
      new_row[:buyer_views] += 1 if REVERSE_EVENTS[row['event']] == :views

      new_row[:buyer_enquiries] = 0 if new_row[:enquiries].nil?
      new_row[:buyer_enquiries] += 1 if ENQUIRY_EVENTS.include?(REVERSE_EVENTS[row['event']])

      new_row[:property_tracking] = 0 if new_row[:property_tracking].nil?
      new_row[:property_tracking] += 1 if REVERSE_EVENTS[row['event']] == :property_tracking

      new_row[:would_view_if_green] = 0 if new_row[:would_view_if_green].nil?
      new_row[:would_view_if_green] += 1 if REVERSE_EVENTS[row['event']] == :would_view_if_green

      new_row[:would_make_offer_if_green] = 0 if new_row[:would_make_offer_if_green].nil?
      new_row[:would_make_offer_if_green] += 1 if REVERSE_EVENTS[row['event']] == :would_make_offer_if_green

      new_row[:requested_message] = 0 if new_row[:requested_message].nil?
      new_row[:requested_message] += 1 if REVERSE_EVENTS[row['event']] == :requested_message

      new_row[:requested_callback] = 0 if new_row[:requested_callback].nil?
      new_row[:requested_callback] += 1 if REVERSE_EVENTS[row['event']] == :requested_callback

      new_row[:enquiry_status] = REVERSE_EVENTS[row['event']] if row['event'] <= EVENTS[:closed_won_stage] || row['event'] >= EVENTS[:qualifying_stage]
      new_row[:confidence_level] = row['message'] if REVERSE_EVENTS[row['event']] == :confidence_level

      if [:responded_to_email_request, :responded_to_callback_request, :responded_to_viewing_request].include?(REVERSE_EVENTS[row['event']])
        new_row[:replied] = true
      end

      events = [:property_tracking, :requested_callback, :requested_message, :requested_viewing, :would_view_if_green, :would_make_offer_if_green]
      if events.include?(REVERSE_EVENTS[row['event']])
        new_row[:type_of_enquiry].push(REVERSE_EVENTS[row['event']])
      end

    end


  end
end

#CREATE KEYSPACE Simple WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };
=begin

DROP TABLE Simple.property_events_buyers ;
DROP TABLE Simple.property_events_buyers_dated ;
DROP TABLE Simple.buyer_events ;
DROP TABLE Simple.property_events_buyers_non_dated;
DROP TABLE Simple.buyer_events_non_dated;

CREATE TABLE Simple.property_events_buyers (
    date text,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((property_id), date, buyer_id, event)
);

CREATE TABLE Simple.property_events_buyers_dated (
    date text,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((date, property_id), buyer_id, event)
);

CREATE TABLE Simple.buyer_events (
    date text,
    buyer_id int,
    property_id text,
    status_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((date), buyer_id, property_id, event)
);

CREATE TABLE Simple.buyer_events_non_dated (
    date text,
    buyer_id int,
    property_id text,
    status_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((buyer_id), date, property_id, event)
);


CREATE TABLE Simple.property_events_buyers_non_dated (
    date text,
    property_id text,
    status_id int,
    buyer_id int,
    event int,
    message text,
    type_of_match int,
    PRIMARY KEY ((property_id), buyer_id, event, date)
);



INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 1, NULL, 1 );
INSERT INTO Simple.property_events_buyers_dated (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 1, NULL, 1 );
INSERT INTO Simple.property_events_buyers_non_dated (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 1, NULL, 1 );
INSERT INTO Simple.buyer_events (date, buyer_id, status_id, property_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 1, NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, status_id, property_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 1, NULL, 1 );


INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 2, NULL, 1  );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 4, NULL, 1  );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 8 , NULL, 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 10 , '2016-12-13', 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 9 , NULL, 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 11 , NULL, 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 14, NULL, 1  );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 19, NULL, 1  );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 12, 18 , NULL, 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '12', 1, 123, 1 , NULL, 1 );
INSERT INTO Simple.property_events_buyers (date, property_id, status_id, buyer_id, event, message, type_of_match) VALUES ( '2016-07-11', '123', 1, 12, 1 , NULL, 1 );


INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12,  '12', 1, 1, NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12,  '12', 1, 2, NULL, 1  );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12,  '12', 1, 4, NULL, 1  );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 8 , NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 10 , '2016-12-13', 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 9 , NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 11 , NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 14, NULL, 1  );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 19, NULL, 1  );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 18 , NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '12', 1, 1 , NULL, 1 );
INSERT INTO Simple.buyer_events_non_dated (date, buyer_id, property_id, status_id, event, message, type_of_match) VALUES ( '2016-07-11', 12, '123', 1, 1 , NULL, 1 );




=end
