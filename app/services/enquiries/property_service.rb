module Enquiries
  class PropertyService
    include EnquiryInfoHelper

    attr_accessor :udprn, :agent_id, :buyer_id, :vendor_id

    def initialize(udprn: property_id, vendor_id: vendor=nil, agent_id: agent=nil, buyer_id: buyer=nil)
      @udprn = udprn
      @vendor_id = vendor_id
      @agent_id ||= agent_id
      @buyer_id ||= buyer_id
    end

    #### Buyer interest details. To test it, just run the following in the irb
    #### Trackers::Buyer.new.interest_info(10966139)
    #### TODO: Fixme: When a udprn can be rent and the buy or vice-versa, it needs to be segregated
    #### And over multiple lifetimes
    def interest_info
      udprn = @udprn.to_i
      property_for = nil
      aggregated_result = {}
      property_id = udprn.to_i
      current_month = Date.today.month

      event = Event::EVENTS[:viewed]
      monthly_views = Events::View.where(udprn: property_id).group(:month).count

      events = Event::ENQUIRY_EVENTS.map { |e| Event::EVENTS[e] }
      monthly_enquiries = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event IN (#{events.join(',')})  AND udprn=#{property_id} ").as_json
      aggregated_result[:enquiries] =  monthly_enquiries
      
      event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
      monthly_property_tracking = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events_tracks WHERE type_of_tracking=#{event}  AND udprn=#{property_id} ").as_json
      aggregated_result[:property_tracking] =  monthly_property_tracking

      Event::ENQUIRY_EVENTS.each do |event|
        result = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events WHERE event=#{Event::EVENTS[event]}  AND udprn=#{property_id} ").as_json
        aggregated_result[event] =  result
      end

      event = Event::EVENTS[:deleted]
      results = Event.connection.execute("SELECT DISTINCT EXTRACT(month FROM created_at) as month,  COUNT(*) OVER(PARTITION BY (EXTRACT(month FROM created_at)) )  FROM events_is_deleteds WHERE udprn=#{property_id} ").as_json
      aggregated_result[:deleted] =  results

      months = (1..12).to_a
      aggregated_result.each do |key, value|
        present_months = value.map { |e| e['month'].to_i }
        missing_months = months.select{ |t| !present_months.include?(t) }
        missing_months.each do |each_month|
          value.push({ 'month': each_month.to_s, count: 0.to_s })
        end
        aggregated_result[key] = value.sort_by{ |t| t['month'].to_i }
      end

      aggregated_result[:monthly_views] = months.map do |month|
        { month:  month.to_s, count: monthly_views[month].to_s }
      end
      aggregated_result
    end

    #### Track the number of searches of similar properties located around that property
    #### Trackers::Buyer.new.demand_info(10966139)
    #### TODO: Integrate it with rent
    def demand_info
      udprn = @udprn.to_i
      details = PropertyDetails.details(udprn.to_i)['_source']
      #### Similar properties to the udprn

      ### Get the distribution of properties according to their property types which match
      ### exactly the buyer requirements
      klass = PropertyBuyer
      query = klass
      query = query.where('min_beds <= ?', details[:beds].to_i) if details[:beds]
      query = query.where('max_beds >= ?', details[:beds].to_i) if details[:beds]
      query = query.where('min_baths <= ?', details[:baths].to_i) if details[:baths]
      query = query.where('max_baths >= ?', details[:baths].to_i) if details[:baths]
      query = query.where('min_receptions <= ?', details[:receptions].to_i) if details[:receptions]
      query = query.where('max_receptions >= ?', details[:receptions].to_i) if details[:receptions]
      query = query.where(" ? = ANY(property_types)", details[:property_type]) if details[:property_type]
      query = query.where.not(status: nil)
      result_hash = query.group(:status).count
      
      distribution = {}
      PropertyBuyer::STATUS_HASH.each do |key, value|
        distribution[key] = result_hash[PropertyBuyer::REVERSE_STATUS_HASH[value]]
        distribution[key] ||= 0
      end
      distribution
    end

    #### Track the number of similar properties located around that property
    #### Trackers::Buyer.new.supply_info(10966139)
    def supply_info
      udprn = @udprn.to_i
      details = PropertyDetails.details(udprn.to_i)['_source']
      #### Similar properties to the udprn
      #### TODO: Remove HACK FOR SOME Results to be shown
      default_search_params = {}
      default_search_params[:max_beds] = default_search_params[:min_beds] = details[:beds].to_i if details[:beds]
      default_search_params[:min_baths] = default_search_params[:max_baths] = details[:baths].to_i if details[:baths]
      default_search_params[:min_receptions] = default_search_params[:max_receptions] = details[:receptions].to_i if details[:receptions]
      default_search_params[:property_type] = details[:property_type] if details[:property_type]
      # p default_search_params

      ### analysis for each of the postcode type
      search_stats = {}
      street = :thoroughfare_description if details[:thoroughfare_description]
      street ||= :dependent_thoroughfare_description if details[:dependent_thoroughfare_description]
      
      [ :dependent_locality, street ].each do |region_type|
        ### Default search stats
        region = region_type
        if region_type == :thoroughfare_description || region_type == :dependent_thoroughfare_description
          region = :street
        else
          region = :locality
        end
        search_stats[region] = {}

        results = []

        if details[region_type] && default_search_params.keys.count > 0
          hash_str = MatrixViewService.form_hash_str(details, region_type)      
          search_params = default_search_params.clone
          search_params[:hash_str] = hash_str
          search_params[:hash_type] = region_type
          search_stats["#{region.to_s}_query_param".to_sym] = search_params.to_query
          # Rails.logger.info(search_params)
          page_counter = 1
          loop do
            search_params[:p] = page_counter
            api = PropertySearchApi.new(filtered_params: search_params)
            body = []
            body, status = api.filter
            break if body[:results].length == 0
            results += body[:results]
            page_counter += 1
          end
          ### Exclude the current udprn from the result
          results = results.select{|t| t[:udprn].to_i != udprn.to_i }
    
          results.each do |each_result|
            search_stats[region][each_result[:property_status_type]] ||= 0 if each_result[:property_status_type]
            search_stats[region][each_result[:property_status_type]] += 1 if each_result[:property_status_type]
          end
        end
        ['Green', 'Amber', 'Red'].each { |status| search_stats[region][status] ||= 0 }
        
      end

      search_stats
    end

    #### Track the number of similar properties located around that property
    #### Trackers::Buyer.new.buyer_intent_info(10966139)
    def buyer_intent_info
      udprn = @udprn.to_i
      details = PropertyDetails.details(udprn.to_i)['_source']
      
      #### Similar properties to the udprn
      default_search_params = {
        min_beds: details['beds'].to_i,
        max_beds: details['beds'].to_i,
        min_baths: details['baths'].to_i,
        max_baths: details['baths'].to_i,
        min_receptions: details['receptions'].to_i,
        max_receptions: details['receptions'].to_i,
        property_status_types: details['property_status_type']
      }

      ### analysis for each of the postcode type
      search_stats = {}
      [ :district, :sector, :unit ].each do |region_type|
        ### Default search stats
        search_stats[region_type] = { green: 0, amber: 0, red: 0 }

        search_params = default_search_params.clone
        search_params[region_type] = details[region_type.to_s]
        search_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        body, status = api.fetch_data_from_es
        udprns = []
        if status.to_i == 200
          udprns = body.map { |e| e['udprn'] }
        end

        ### Exclude the current udprn from the result
        udprns = udprns - [ udprn.to_s ]
        # p udprns
        ### Accumulate buyer_id for each udprn
        buyer_ids = []
        event = Event::EVENTS[:save_search_hash]
        query = Event
        buyer_ids = query.where(event: event).where(udprn: udprns).pluck(:buyer_id).uniq

        ### Extract status of the buyers in bulk
        buyers = PropertyBuyer.where(id: buyer_ids).select([:id, :status])

        buyers.each do |each_buyer_info|
          buyer_status = PropertyBuyer::REVERSE_STATUS_HASH[each_buyer_info.status]
          search_stats[region_type][buyer_status] += 1
        end

        search_stats[region_type][:total] = search_stats[region_type][:green] + search_stats[region_type][:red] + search_stats[region_type][:amber]

        if search_stats[region_type][:total] > 0
          search_stats[region_type][:green_percent] = ((search_stats[region_type][:green].to_f/search_stats[region_type][:total].to_f)*100).round(2)
          search_stats[region_type][:amber_percent] = ((search_stats[region_type][:red].to_f/search_stats[region_type][:total].to_f)*100).round(2)
          search_stats[region_type][:red_percent] = ((search_stats[region_type][:amber].to_f/search_stats[region_type][:total].to_f)*100).round(2)
        else
          search_stats[region_type][:green_percent] = nil
          search_stats[region_type][:amber_percent] = nil
          search_stats[region_type][:red_percent] = nil
        end
      end
      search_stats
    end

    #### Methods for the pie charts have been defined below
    ##### Information about pie charts about the buyer. All related to the buyer
    #### To try this method run the following in the console
    #### Trackers::Buyer.new.buyer_profile_stats(10976419)
    #### TODO: This has lot of attributes relevant for Sale
    #### Have to fork a new method for Rent
    def buyer_profile_stats
      result_hash = {}
      property_id = @udprn.to_i
      details = PropertyDetails.details(udprn.to_i)['_source'] rescue {}
      #event = Event::EVENTS[:save_search_hash]

      query = Event
      buyer_ids = query.where(udprn: property_id).pluck(:buyer_id).uniq
      ### Buying status stats
      buying_status_distribution = PropertyBuyer.where(id: buyer_ids).where.not(buying_status: nil).group(:buying_status).count
      p buyer_ids
      total_count = buying_status_distribution.inject(0) do |result, (key, value)|
        result += value
      end
      buying_status_stats = {}
      buying_status_distribution.each do |key, value|
        buying_status_stats[PropertyBuyer::REVERSE_BUYING_STATUS_HASH[key]] = ((value.to_f/total_count.to_f)*100).round(2)
      end
      PropertyBuyer::BUYING_STATUS_HASH.each { |k,v| buying_status_stats[k] = 0 unless buying_status_stats[k] }

      result_hash[:buying_status] = buying_status_stats

      ### Funding status stats
      funding_status_distribution = PropertyBuyer.where(id: buyer_ids).where.not(funding: nil).group(:funding).count
      total_count = funding_status_distribution.inject(0) do |result, (key, value)|
        result += value
      end
      funding_status_stats = {}
      funding_status_distribution.each do |key, value|
        funding_status_stats[PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[key]] = ((value.to_f/total_count.to_f)*100).round(2)
      end
      PropertyBuyer::FUNDING_STATUS_HASH.each { |k,v| funding_status_stats[k] = 0 unless funding_status_stats[k] }
      result_hash[:funding_status] = funding_status_stats

      ### Biggest problem stats
      biggest_problem_distribution = PropertyBuyer.where(id: buyer_ids).where.not(biggest_problems: nil).group(:biggest_problems).count
      total_count = biggest_problem_distribution.inject(0) do |result, (key, value)|
        result += (value*(key.length))
      end
      biggest_problem_stats = {}
      biggest_problem_distribution.each do |keys, value|
        keys.each do |key|
          biggest_problem_stats[key] = ((value.to_f/total_count.to_f)*100).round(2)
        end
      end
      PropertyBuyer::BIGGEST_PROBLEM_HASH.each { |k,v| biggest_problem_stats[k] = 0 unless biggest_problem_stats[k] }
      result_hash[:biggest_problem] = biggest_problem_stats

      ### Chain free stats
      chain_free_distribution = PropertyBuyer.where(id: buyer_ids).where.not(chain_free: nil).group(:chain_free).count
      total_count = chain_free_distribution.inject(0) do |result, (key, value)|
        result += value
      end
      chain_free_stats = {}
      chain_free_distribution.each do |key, value|
        chain_free_stats[key] = ((value.to_f/total_count.to_f)*100).round(2)
      end
      chain_free_stats[true] = 0 unless chain_free_stats[true]
      chain_free_stats[false] = 0 unless chain_free_stats[false]
      chain_free_stats['Yes'] = chain_free_stats[true]
      chain_free_stats['No'] = chain_free_stats[false]
      chain_free_stats.delete(true)
      chain_free_stats.delete(false)
      result_hash[:chain_free] = chain_free_stats
      result_hash
    end

    #### The following method gets the data for qualifying stage and hotness stats
    #### for the agents.
    #### Trackers::Buyer.new.agent_stage_and_rating_stats(10966139)
    def agent_stage_and_rating_stats
      udprn = @udprn.to_i
      aggregate_stats = {}
      property_id = udprn.to_i
      query = Event
      stats = query.where(udprn: udprn).group(:stage).count
      stage_stats = {}

      sum_count = 0
      stats.each do |key, value|
        stage_stats[Event::REVERSE_EVENTS[key.to_i]] = value
        sum_count += value.to_i
      end
      #stage_stats.merge!(count_stats)
      Event::QUALIFYING_STAGE_EVENTS.each {|t| stage_stats[t] ||= 0 }

      aggregate_stats[:buyer_enquiry_distribution] = stage_stats

      rating_stats = {}

      Event::HOTNESS_EVENTS.reverse.each {|t| rating_stats[t] ||= 0 }
      query = Event
      sum_count = 0
      stats = query.where(udprn: udprn).group(:rating).count
      stats.each do |key, value|
        rating_stats[Event::REVERSE_EVENTS[key.to_i]] = value
        sum_count += value.to_i
      end

      aggregate_stats[:rating_stats] = rating_stats
      aggregate_stats
    end

    #### The following method gets the data for qualifying stage and hotness stats
    #### for the agents.
    #### Trackers::Buyer.new.ranking_stats(10966139)
    def ranking_stats
      udprn = @udprn.to_i
      property_id = udprn
      details = PropertyDetails.details(udprn)['_source']
      #### Similar properties to the udprn
      default_search_params = {
        min_beds: details['beds'].to_i,
        max_beds: details['beds'].to_i,
        min_baths: details['baths'].to_i,
        max_baths: details['baths'].to_i,
        min_receptions: details['receptions'].to_i,
        max_receptions: details['receptions'].to_i,
        property_types: details['property_type']
      }

      ### analysis for each of the postcode type
      ranking_stats = {}
      [ :district, :sector, :unit ].each do |region_type|
        ### Default search stats
        ranking_stats[region_type] = {
          view_ranking: nil,
          total_enquiries_ranking: nil,
          tracking_ranking: nil,
          would_view_ranking: nil,
          would_make_an_offer_ranking: nil,
          message_requested_ranking: nil,
          callback_requested_ranking: nil,
          requested_viewing_ranking: nil,
          deleted_ranking: nil
        }

        search_params = default_search_params.clone
        search_params[region_type] = details[region_type.to_s]
        ranking_stats[region_type][:value] = details[region_type.to_s] ### Populate the value of sector, district and unit
        ##Rails.logger.info(search_params)
        api = PropertySearchApi.new(filtered_params: search_params)
        api.apply_filters
        body, status = api.fetch_udprns
        udprns = []
        udprns = body.map(&:to_i)  if status.to_i == 200
        ### Accumulate all stats for each udprn
        total_enquiry_hash = save_search_hash = view_hash = would_view_hash = tracking_hash = requested_message_hash = {}
        hidden_hash = would_make_an_offer_hash = requested_callback_hash = requested_viewing_hash = {}
        table = nil
        udprns.each do |udprn|
          udprn = udprn.to_i
          property_stat = Events::EnquiryStatProperty.new(udprn: udprn)
          view_hash[udprn] = property_stat.views
          total_enquiry_hash[udprn] = property_stat.enquiries

          event = Events::Track::TRACKING_TYPE_MAP[:property_tracking]
          tracking_hash[udprn] = Events::Track.where(type_of_tracking: event).where(udprn: property_id).count
          would_view_hash[udprn] = property_stat.specific_enquiry_count(:interested_in_viewing)
          would_make_an_offer_hash[udprn] = property_stat.specific_enquiry_count(:interested_in_making_an_offer)
          requested_message_hash[udprn] = property_stat.specific_enquiry_count(:requested_message)
          requested_viewing_hash[udprn] = property_stat.specific_enquiry_count(:requested_viewing)
          requested_callback_hash[udprn] = property_stat.specific_enquiry_count(:requested_callback)
          hidden_hash[udprn] = Events::IsDeleted.where(udprn: property_id).count
        end
        ranking_stats[region_type][:total_properties] = udprns.count
        ranking_stats[region_type][:view_ranking] = rank(view_hash, property_id)
        ranking_stats[region_type][:total_enquiries_ranking] = rank(total_enquiry_hash, property_id)
        ranking_stats[region_type][:tracking_ranking] = rank(tracking_hash, property_id)
        ranking_stats[region_type][:would_view_ranking] = rank(would_view_hash, property_id)
        ranking_stats[region_type][:would_make_an_offer_ranking] = rank(would_make_an_offer_hash, property_id)
        ranking_stats[region_type][:message_requested_ranking] = rank(requested_message_hash, property_id)
        ranking_stats[region_type][:callback_requested_ranking] = rank(requested_callback_hash, property_id)
        ranking_stats[region_type][:requested_viewing_ranking] = rank(requested_viewing_hash, property_id)
        ranking_stats[region_type][:deleted_ranking] = rank(hidden_hash, property_id)
      end
      ranking_stats
    end


  end
end
