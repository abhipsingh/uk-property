#### Potential results API
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/api/v0/properties/search?hash_str=HEREFORD_City%20Centre_Lingen%20Avenue&hash_type=text&match_type=Potential&buyer_status=Green&max_budget=130000
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Matrix view API filtered by filters
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/addresses/matrix_view?str=Lingen%20Avenue&match_type=Potential&buyer_status=Green
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Featured type APIs
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/api/v0/properties/search?hash_str=HEREFORD_City%20Centre_Lingen%20Avenue&hash_type=text&match_type=Potential&buyer_status=Amber&max_budget=160000&listing_type=Featured
#### --------------------------------------------------------------------------------------------------------------------------------------
#### Featured type APIs
#### http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/addresses/predictions?str=Lingen%20Avenue
#### --------------------------------------------------------------------------------------------------------------------------------------

module Api
  module V0
    class PropertySearchController < ActionController::Base
      include EventsHelper
      def search
        response = Hash.new
        api = ::PropertyDetailsRepo.new(filtered_params: params)
        result, status = api.filter
        #result[:results].map{ |t| add_new_keys(t) }
        result = result[:results].sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = [] }
        Rails.logger.info(result)
        result.first[:breadcrumb] = params[:hash_str].split('_').join(', ')
        result.each { |each_property| insert_save_search(each_property) }
        
        render :json => result, :status => status
      end

      def insert_save_search(property_detail)
        event = Trackers::Buyer::EVENTS[:save_search_hash]
        buyer_id = params['buyer_id'].to_i
        agent_id = property_detail['agent_id'].to_i

        Rails.logger.info("AGENT_ID____#{agent_id}")

        property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[property_detail['property_status_type']]

        #### Search hash of a message
        message = params[:message]

        params[:match_type] ||= 'perfect' 
        type_of_match = Trackers::Buyer::TYPE_OF_MATCH[params[:match_type].downcase.to_sym]
        # type_of_match = Trackers::Buyer::TYPE_OF_MATCH.with_indifferent_access[params[:type_of_match]]

        property_id = property_detail['udprn'].to_i
        message = 'NULL' if message.nil?
        insert_events(agent_id, property_id, buyer_id, message, type_of_match, property_status_type, event)
      end

       def add_new_keys(result)
        characters = (1..10).to_a
        alphabets = ('A'..'Z').to_a
        start_date = 3.months.ago
        ending_date = 4.hours.ago
        years = (1955..2015).step(10).to_a
        time_frame_years = (2004..2016).step(1).to_a
        days = (1..24).to_a
        ::PropertyDetailsRepo::RANDOM_SEED_MAP.each do |key, values|
          result[key] = values.sample(1).first
        end
        result[:date_added] = Time.at((start_date.to_f - ending_date.to_f)*rand + start_date.to_f).utc.strftime('%Y-%m-%d %H:%M:%S')
        result[:time_frame] = time_frame_years.sample(1).first.to_s + "-01-01"
        result[:external_property_size] = result[:internal_property_size] + 100
        result[:total_property_size] = result[:external_property_size] + 100
        result[:budget] = result[:price]

        if result[:photos] == "Yes"
          result[:photo_count] = 3
          result[:photo_urls] = [
            "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop.jpg",
            "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop2.jpg",
            "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop3.jpg",
          ]
        else
          result[:photo_urls] = []
        end

        result[:agent_logo] = "http://ec2-52-66-124-42.ap-south-1.compute.amazonaws.com/prop3.jpg"
        result[:agent_contact] = "020 3641 4259"
        result[:agent_branch_name] = "XYZ Branch"
        result[:assigned_agent_employee_name] = "John Smith"
        result[:assigned_agent_employee_address] = "5 Bina Gardens"
        result[:assigned_agent_employee_image] = nil
        result[:last_updated_date] = "2015-09-21"
        result[:assigned_agent_employee_number] = "9999999999"
        result[:added_by_name] = "Agent 1"
        result[:verification] = true
        result[:title] = "Random title"
        result[:dream_price] = 100000
        result[:valuation] = '2014-09-12'
        result[:valuation_date] = 5000
        result[:last_sale_price] = 1600
        result[:last_sale_price_date] = '2014-09-12'
        description = ''
        result[:description] = "Lorem ipsum"
        result[:interested_in_view] = '/api/v0/vendors/update/property_users?action_type=interested_in_view'
        result[:request_a_view] = '/api/v0/vendors/update/property_users?action_type=request_a_view'
        result[:make_offer] = '/api/v0/vendors/update/property_users?action_type=make_offer'
        result[:follow_street] = '/addresses/follow?location_type=dependent_thoroughfare_description'
        result[:follow_locality] = '/addresses/follow?location_type =dependent_locality'
      end

      def new_property
        new_params = params.deep_dup
        int_attrs = ['beds', 'baths', 'receptions', 'floors', 'offers_above_x', 'most_recent_price_value', 
                     'montly_rent_value', 'vendor_personal_valuation', 'current_agent_valuation']

        new_params['cost_per_month'] = ['water_cost', 'lighting_cost', 'heating_cost', 'council_cost'].inject(0) { |mem, var| mem += new_params[var].to_i }
        new_params['cost_per_month'] += ['ground_rent_cost', 'annual_service_cost', 'parking_cost'].inject(0) { |mem, var| mem += (new_params[var].to_i / 12) }
        
        int_attrs.map { |e| new_params[e] = new_params[e].to_i  }
        
        if new_params['internal_property_size'] != "Don't know"
          new_params['internal_property_size'] = new_params['property_sizes']['0']['prop_area'].to_i
        end
        
        if new_params['external_property_size'] != "Don't know"
          new_params['external_property_size'] = new_params['property_sizes']['1']['prop_area'].to_i
        end

        case new_params['year_built']
        when 'Under 10 years ago'
          new_params['year_built'] = 10.years.ago.to_date.to_s
        when 'Under 25 years ago'
          new_params['year_built'] = 25.years.ago.to_date.to_s
        when 'Under 50 years ago'
          new_params['year_built'] = 50.years.ago.to_date.to_s
        when 'Over 50 years ago'
          new_params['year_built'] = (50.years.ago - 24.hours).to_date.to_s
        end

        new_params['total_property_size'] = new_params['internal_property_size'].to_i + new_params['external_property_size'].to_i
        delete_attrs = ['water_cost', 'lighting_cost', 'heating_cost', 'council_cost', 'ground_rent_cost', 'annual_service_cost',
                        'parking_cost', 'prop_area', 'room_width', 'room_length', 'property_sizes', 'action', 
                        'controller', 'udprn']

        if new_params['room_details']
          new_params['room_details'] = new_params['room_details'].map { |h,k| k }
          new_params['room_details'].map { |e| e['room_length'] = e['room_length'].to_i && e['room_width'] = e['room_width'].to_i  }
        end
        
        if new_params['improvement_spends']
          new_params['improvement_spends'] = new_params['improvement_spends'].map { |h,k| k }
          new_params['improvement_spends'].map { |e| e['improvement_value'] = e['improvement_value'].to_i }  
        end
        
        delete_attrs.map { |e| new_params.delete(e)  }
        
        client = Elasticsearch::Client.new
        response = client.update index: 'addresses', type: 'address', id: params['udprn'],
                                 body: { doc: new_params }


        render json: { message: 'Success' }, status: 200
      end


      def update_viewed_flats
        udprns = params[:udprns].split(',')
        property_user_id = params[:property_user_id]
        client = Elasticsearch::Client.new
        doc = client.get index: 'property_users', type: 'property_user', id: property_user_id
        updated_udprns = doc['_source']['udprns'] + udprns
        res = client.update index: 'property_users', type: 'property_user', id: property_user_id, 
                          body: { doc: { udprns: updated_udprns } }
        ### Todo update flats visited by the user
        render json: { message: 'User successfully updated' }
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        render json: { message: 'User Not found' }, status: 404
      end

      def notify_vendor_of_users
        property_user_id = params[:property_user_id]
        udprn = params[:udprn]
        email = params[:email]
        number = params[:number]
        action_type = params[:action_type]
        vendor_id = params[:vendor_id]
        client = Elasticsearch::Client.new
        vendor_doc = client.get index: 'vendors', type: 'vendor', id: vendor_id
        #### Notify vendor and update the backend
        render json: { message: 'Vendor notified', email: vendor_doc[:email], number: vendor_doc[:number] }, status: 200
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        render json: { message: 'Vendor not found' }, status: 404
      end

      def update_shortlisted_udprns
        udprns = params[:udprns].split(',')
        property_user_id = params[:property_user_id]
        client = Elasticsearch::Client.new
        doc = client.get index: 'property_users', type: 'property_user', id: property_user_id
        updated_udprns = doc['_source']['shortlisted_udprns'] + udprns
        res = client.update index: 'property_users', type: 'property_user', id: property_user_id, 
                          body: { doc: { shortlisted_udprns: updated_udprns } }

        render json: { message: 'User successfully updated' }
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        render json: { message: 'User Not found' }, status: 404
      end

      def save_searches
        saved_flag = true
        messages = [],
        searches = nil
        PropertyBuyer.where(email_id: params[:email_id]).each do |property_buyer|
          searches = property_buyer.searches
          new_search_hash = params[:new_search]
          if validate_search_hash(new_search_hash)
            searches.push(new_search_hash)
            property_buyer.searches = searches
            saved_flag = property_buyer.save
            messages = property_buyer.errors.messages
          end
        end
        if saved_flag
          render json: {searches: searches}, status: 200
        else
          render json: {errors: messages}, status: 400
        end
      end

      def show_save_searches
        searches, name, email_id = nil
        PropertyBuyer.where(email_id: params[:email_id]).select([:email_id, :name, :searches]).each do |property_buyer|
          searches = property_buyer.searches
          name = property_buyer.name
          email_id = property_buyer.email_id
        end
        if searches.nil?
          render json: {message: 'Email not found'}, status: 404
        else
          render json: { searches: searches, email_id: email_id, name: name }
        end
      end

      def validate_search_hash(search_hash)
        result = true
        result = result && search_hash.is_a?(Hash)
        result = result && search_hash.keys.count == 2 if result
        result = result && search_hash.keys.include?('name') if result
        result = result && search_hash.keys.include?('search_hash') if result
        result
      end

    end
  end
end
