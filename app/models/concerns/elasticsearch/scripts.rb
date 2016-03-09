module Elasticsearch::Scripts
  extend ActiveSupport::Concern
  included do
    @@boost_hash = {:furnish_type_id => 1, :apartment_type_id => 2, :price_range => 2, 
                  :date_range => [
                    {min_date: (Time.now - 5.days).to_i, max_date: Time.now.to_i, boost: 20}, 
                    {min_date: (Time.now - 15.days).to_i, max_date: (Time.now - 5.days).to_i, boost: 13}, 
                    {min_date: (Time.now - 30.days).to_i, max_date: (Time.now - 15.days).to_i, boost: 7},
                    {min_date: 0, max_date: (Time.now - 30.days).to_i, boost: 0}]  
    }
    @@threshold_distance = 10 #km
    @@earth_perimeter_threshold = 42000 #km

    def view_count_script_sorting
      inst = self
      hash = {
        _script: {
          # script: "date_added",
          script: "doc['view_count'].value + (ceil((date_added - doc['date_added_in_seconds'].value)/seconds_per_interval))*20",
          type: "number",
          lang: "groovy",
          params:{
            lat: @filtered_params[:latitude].to_f,
            lon: @filtered_params[:longitude].to_f,
            seconds_per_interval: (24*60*60),
            date_added: Time.now.to_i
          },
          order: "asc"
        }
      }
      inst = inst.append_custom_sorting(hash)
      return inst
    end
    
    def seo_script_query_sorting
      inst = self
      if SeoFilterHelper.nofollow(@filtered_params)
        filter_tags = Array.new
        address_tags = Array.new
        should_query = Array.new
        must_query = Array.new
        filter_tags_hash = @filtered_params.slice(:apartment_types,:property_types,:furnish_types,:owner_types)
        filter_tags_hash.keys.each do |key|
          filter_tags_hash[key].split(",").each do |entity_id|
            filter_tags.push (SeoTagMapping.get_tags(key.to_s,entity_id)) rescue nil
          end
        end
        # put region name in filtered hash
        address_tags.push(@filtered_params[:region_name]) if @filtered_params[:region_name]
        tags = filter_tags + address_tags
        filter_tags.each do |tag|
          query_hash = { constant_score: { query: { match: { seo_tags: tag } } } }
          should_query.push(query_hash)
        end
        address_tags.each do |tag|
          query_hash =  { constant_score: { query: { match: { seo_tags: tag } }, boost: tags.length } }
          should_query.push(query_hash)
        end
        filters = @query[:query][:filtered][:filter]
        must_query.push({ constant_score: { filter: filters, boost: 0 } })
        date_added = Date.today.to_time.to_i
        query = {
                  function_score: {
                    query: { 
                      bool: {
                        should: should_query,
                        must: must_query
                      }
                    },
                    script_score: {
                      lang: 'groovy',
                      params: {
                        today: date_added,
                        ideal_score:  (2*(tags.length) - 1).to_f,
                        seconds_per_interval: (24*60*60*1.0*15)
                      },
                      script: "(_score/ideal_score) - (today - doc['date_added_in_seconds'].value)/seconds_per_interval"
                    },
                    boost_mode: 'replace',
                    score_mode: 'sum'
                  }
                }
        inst.append_query_sorting(query)
      end
      return inst
    end

    def fallback_listing
      inst = self
      query = {bool: {should: build_date_bucketing}}
      inst.append_query_sorting(query)
      return inst
    end 

    def to_radians(degrees)
      return degrees * Math::PI / 180 
    end
    
    def get_distance(lat1, lng1, lat2, lng2)
      lat1 = to_radians(lat1)
      lon1 = to_radians(lng1)
      lat2 = to_radians(lat2)
      lon2 = to_radians(lng2)
      dlon = lon2 - lon1
      dlat = lat2 - lat1
      a = (Math.sin(dlat / 2)) ** 2 + Math.cos(lat1) * Math.cos(lat2) * (Math.sin(dlon / 2)) ** 2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      return(6373.0 * c)
    end

    def centroid_distance(result)
      return @@earth_perimeter_threshold unless result["centroid"].present?
      latitude = result["centroid"]["latitude"]
      longitude = result["centroid"]["longitude"]
      if @filtered_params[:polygon_center].present?
        centroid_to_polygon_distance = get_distance(result["centroid"]["latitude"],
                                                    result["centroid"]["longitude"], 
                                                    @filtered_params[:polygon_center][1],
                                                    @filtered_params[:polygon_center][0])
       return centroid_to_polygon_distance
      else
        return @@earth_perimeter_threshold
      end
    end

    def get_best_profile(profiles)
      best_profile_distance = 0
      best_profile = profiles.inject do |best_profile, profile|
        if(profile[1].class.to_s == "Hash")
          profile_distance = centroid_distance(profile[1])
          best_profile_distance = centroid_distance(best_profile[1])
          if(profile_distance < best_profile_distance)
            best_profile = profile
            best_profile_distance = profile_distance
          end
        end
        best_profile 
      end
      best_profile = best_profile[1] rescue nil
      return best_profile if best_profile_distance < @@threshold_distance 
    end

    def build_es_query(should_query, must_query, rent_mean)
      query = {
            function_score: {
              query: { 
                bool: {
                  should: should_query,
                  must: must_query
                }
              },
              script_score: {
                lang: "groovy",
                params: {
                  intent_price: rent_mean
                },
                script: "2*(1 - min(1, abs((intent_price - doc['rent'].value) / intent_price)))"
              },
              score_mode: "sum",
              boost_mode: "sum"
            }
          }
    end

    def build_date_bucketing
      date_buckets = Array.new
      @@boost_hash[:date_range].each do |time_range|
        date_query = { constant_score: { filter: { range: { "date_added_in_seconds" => { from: time_range[:min_date] ,to: time_range[:max_date]}}}, boost: time_range[:boost]}}
        date_buckets.push(date_query)
      end 
      return date_buckets
    end

    def other_filter_boost(result, should_query)
      atomic_intent_list = ["furnish_type", "apartment_type_id"]
      atomic_intent_list.each do |key|
        atomic_intent = result["intent"].select {|atomic_intent| atomic_intent["element"].has_key?(key)}.first
        filter_val = atomic_intent["element"][key]
        key = "furnish_type_id" if key == "furnish_type"
        query = { constant_score: { filter: { term: { key.to_sym => filter_val}}, boost: @@boost_hash[key.to_sym]}}
        should_query.push(query)
      end
      return should_query
    end

    def form_query(result,rent_mean)
      must_query = Array.new
      #date bucketing
      should_query = build_date_bucketing
      #other filter boost
      should_query = other_filter_boost(result, should_query)
      filters = @query[:query][:filtered][:filter]
      #Original filters
      must_query.push({ constant_score: { filter: filters, boost: 0 } }) 
      query = build_es_query(should_query, must_query, rent_mean)
    end

    def return_key_single_intent(intent, key)
      return intent.select {|atomic_intent| atomic_intent["element"].has_key?(key)}.first["element"]
    end

    def find_user_polygon(polygon_uuid, intents)
      return nil if intents.empty?
      pid = "polygon_uuid"
      selected_intent = intents.find{|x| return_key_single_intent(x["intent"],pid)[pid]==polygon_uuid}
      return selected_intent
    end

    def get_user_profile_intents(service, uid, polygon_uuid)
      uri = URI("#{Housing.housing_data_url}profile/v3/#{service}?user_id=#{uid}&polygon_uuid=#{polygon_uuid}")
      response = Net::HTTP.get_response(uri)
      if response.code == "200"
        parsed_json = JSON.parse(response.body) rescue nil
        if ((parsed_json==nil) || (parsed_json["status"].to_s.downcase != "success"))
          profile = nil
        else
          all_profiles = parsed_json["data"]["profiles"]
          profile = find_user_polygon(polygon_uuid, all_profiles["user"]["intents"]) rescue nil
          profile = all_profiles["polygon"]["intents"].first rescue nil if profile.nil?
        end
      else
        profile = nil
      end
      return profile
    end

    def user_script_query_sorting(service)
      inst = self
      uid = @filtered_params[:user]
      polygon_uuid = @filtered_params[:poly]
      begin
        result = get_user_profile_intents(service, uid, polygon_uuid)
        if result.present?
          rent_range = return_key_single_intent(result["intent"],"rent")
          rent_mean = (rent_range["rent"]["start"]+rent_range["rent"]["end"])/2
          return fallback_listing if rent_mean == 0

          @filtered_params[:profile_used] = true 
          query = form_query(result,rent_mean)
          inst.append_query_sorting(query)
          return inst
        else
          return fallback_listing
        end
      rescue
        return fallback_listing
      end
    end
  end
end
