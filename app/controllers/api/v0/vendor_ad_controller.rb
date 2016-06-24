module Api
  module V0
    class VendorAdController < ActionController::Base
      def ads_availablity
        score_map = {
          'county' => 6,
          'post_town' => 5,
          'dependent_locality' => 4,
          'double_dependent_locality' => 4,
          'thoroughfare_descriptor' => 3,
          'dependent_thoroughfare_description' => 3
        }
        users = params[:users]
        location_parameters = params.deep_dup
        location_parameters["addresses"].map { |t| t.strip! }
        values = location_parameters["addresses"]
        values = values.map { |e| e.downcase }
        init_values = values
        values = values.reverse
        len = values.length
        query = {}
        count = 0
        index = values.length - 1
        values.each do |value|
          if count == 0
            text_val = value
          else
            if count > 1
              text_val = init_values[(len - 1 - count), (len - 2)].join(' ')
            else
              text_val = init_values[(len - 1 - count), (len - 1)].join(' ')
            end
          end
          query[(values.length - count - 1).to_s] = {
            text: text_val,
            completion: {
              field: :suggest,
              size: 1
            }
          }
          
          count += 1
        end
        response, status = post_url('locations', '_suggest', query)
        response = JSON.parse(response).except("_shards")
        filter_query = {
          _source: {
            include: [:premium_count, :type_value, :featured_count, :version, :premium_buyers, :featured_buyers]
          },
          filter: {
            or: {
              filters: []
            }
          }
        }

        and_filter = {
          and: {
            filters: []
          }
        }


        response.each do |key, value|
          if value[0]["options"].length > 0
            new_and_filter = and_filter.deep_dup
            hash = value[0]["options"].first["payload"]["hash"]
            type = value[0]["options"].first["payload"]["type"]
            new_and_filter[:and][:filters].push( { term: { hashes: hash } } )
            new_and_filter[:and][:filters].push( { term: { type_value: type } } )
            new_and_filter[:and]['_name'] = key
            filter_query[:filter][:or][:filters].push( new_and_filter )
          end

        end
        response, code = post_url('locations', '_search', filter_query)
        response = JSON.parse(response)['hits']['hits']

        ads_query = {
          size: 10,
          _source: {
            include: [:created_at]
          },
          "sort"=> [
             {
                "created_at"=> {
                   "order"=> "asc"
                }
             }
          ],
          filter: {
            or: {
              filters: []
            }
          }
        }

        response.each do |value|
          if value['_source']['premium_count'] == 0
            new_and_filter = and_filter.deep_dup
            new_and_filter[:and][:filters].push({ term: { location_id: value['_id'] } })
            new_and_filter[:and][:filters].push({ term: { type_of_ad: 'premium_count' } })
            new_and_filter[:and][:filters].push({ not:  { term: { entity_id: users } } } )
            new_and_filter[:and]['_name'] = value['_id'] + '|premium'
            ads_query[:filter][:or][:filters].push( new_and_filter )
          elsif value['_source']['featured_count'] == 0
            new_and_filter = and_filter.deep_dup
            new_and_filter[:and][:filters].push({ term: { location_id: value['_id'] } })
            new_and_filter[:and][:filters].push({ term: { type_of_ad: 'featured_count' } })
            new_and_filter[:and][:filters].push({ not:  { term: { entity_id: users } } } )
            new_and_filter[:and]['_name'] = value['_id']+'|featured'
            ads_query[:filter][:or][:filters].push( new_and_filter )
          end

          new_and_filter = and_filter.deep_dup
          new_and_filter[:and][:filters].push({ term: { location_id: value['_id'] } })
          new_and_filter[:and][:filters].push({ term: { type_of_ad: 'featured_count' } })
          new_and_filter[:and][:filters].push({ term: { entity_id: users }})
          new_and_filter[:and]['_name'] = 'entity_ads_featured_'+ value['_id'] + users
          ads_query[:filter][:or][:filters].push( new_and_filter )

          new_and_filter = and_filter.deep_dup
          new_and_filter[:and][:filters].push({ term: { location_id: value['_id'] } })
          new_and_filter[:and][:filters].push({ term: { type_of_ad: 'premium_count' } })
          new_and_filter[:and][:filters].push({ term: { entity_id: users } } )
          new_and_filter[:and]['_name'] = 'entity_ads_premium_'+ value['_id'] + users
          ads_query[:filter][:or][:filters].push( new_and_filter )


          if value['_source']['premium_buyers'].include?(users)
            value['_source']['premium_booked'] = true
          end
          if value['_source']['featured_buyers'].include?(users)
            value['_source']['featured_booked'] = true
          end
        end

        final_response = {}
        response.each do |inner_response|
          inner_response[:score] = score_map[inner_response['_source']['type_value']]
        end
        entries = response.select{|t| ['dependent_thoroughfare_description', 'thoroughfare_descriptor'].include?(t['_source']['type_value']) }
        if entries.empty?
          cloned_response = response.first.clone
          cloned_response[:dummy] = true
          cloned_response[:score] = 3
          response.push(cloned_response)
        end
        entries = response.select{|t| ['dependent_locality', 'double_dependent_locality'].include?(t['_source']['type_value']) }
        if entries.empty?
          cloned_response = response.first.clone
          cloned_response[:dummy] = true
          cloned_response[:score] = 4
          response.push(cloned_response)
        end
        final_response[:availability_count] = response.sort_by{|t| t[:score]}
        if ads_query[:filter][:or][:filters].empty?
          final_response['ads_availablity'] = {}
        else
          response, code = post_url('property_ads', '_search', ads_query)
          response = JSON.parse(response)['hits']['hits']
          Rails.logger.info(response)
          modified_response = {}
          sorted_map = Hash.new { 0 }
          response.each do |value|
            if modified_response[value['matched_queries'].first].nil?
              value['_source']['created_at'] = (Date.parse(value['_source']['created_at']) - Date.today).to_i.to_s + ' days remaining'
              modified_response[value['matched_queries'].first] = value.except('matched_queries')
            end
          end
          final_response[:ads_availability] = modified_response
        end
        render json: final_response, status: code
      end

      def update_availability
        charge = nil
        begin
          params[:stripeAmount] = 100
          amount = params[:stripeAmount].to_i * 100
       
          # Create the customer in Stripe
          customer = Stripe::Customer.create(
            email: params[:stripeEmail],
            card: params[:stripeToken]
          )
       
          # Create the charge using the customer data returned by Stripe API
          charge = Stripe::Charge.create(
            customer: customer.id,
            amount: amount,
            description: 'Rails Stripe customer',
            currency: 'usd'
          )
            # place more code upon successfully creating the charge
        rescue Stripe::CardError => e
          # flash[:error] = e.message
          # redirect_to charges_path
          # flash[:notice] = "Please try again"
        end
        client = Elasticsearch::Client.new
        message = {} 
        status = nil
        arr_of_details = params[:arr_of_locations]
        version_id_map = {}
        featured_buyers_id_map = {}
        premium_buyers_id_map = {}
        indexes = []
        versions = {}
        row_responses = {}
        arr_of_details.each do |key, each_detail|
          id = each_detail[:id]
          type = each_detail[:type]
          version = each_detail[:version].to_i
          value = each_detail[:value].to_i
          users = params[:users]
          premium_buyers = each_detail[:premium_buyers].split(',')
          featured_buyers = each_detail[:featured_buyers].split(',')
          if value > 0
            if type == 'featured_count'
              featured_buyers |= [users]
              featured_buyers_id_map[id] = featured_buyers
              premium_buyers_id_map[id] ||= premium_buyers
            else
              premium_buyers |= [users]
              premium_buyers_id_map[id] = premium_buyers
              featured_buyers_id_map[id] ||= featured_buyers
            end
            begin
              p "#{version}_#{id}"
              if version_id_map[id]
                version_id_map[id] += 1
              else
                version_id_map[id] = version + 1
              end
              versions[id] = version_id_map[id]
              row_responses[id] = each_detail
              response = client.update index: 'locations', type: 'location', id: id, version: version_id_map[id], 
                                       body: { doc: { type => (value - 1), version: version_id_map[id],
                                               featured_buyers: featured_buyers_id_map[id], premium_buyers: premium_buyers_id_map[id] } }

              row_responses[id][:result] = true
              
              new_ad = {
                location_id: id,
                property_id: users,
                type_of_ad: type,
                entity_id: users,
                created_at: 30.days.from_now.to_date.to_s
              }
              response = client.index index: 'property_ads', type: 'property_ad', body: new_ad
              expriry_date = 30.days.from_now.to_date.to_s
              message[:message] = 'Successful'
              message[:expiry_date] = expriry_date
              message[:versions] = versions
              message[:rows] = row_responses
              status = 200 unless status
            rescue Elasticsearch::Transport::Transport::Errors::Conflict => e
              doc = client.get index: 'locations', type: 'location', id: id
              res = client.update index: 'locations', type: 'location', id: id, version: doc['_version'],
                            body: { doc: { version: doc['_version'] } }
              versions[id] = doc['_version']

              row_responses[id][:result] = false

              re = Stripe::Refund.create(
                charge: charge.id,
                amount: each_detail[:elem_price]
              )
              p re.as_json
              message[:message] = 'Conflict'
              message[:versions] = versions
              message[:rows] = row_responses
              status = 400
            rescue Exception => e
              Rails.logger.info(e)
              message = { message: 'Some error occured', rows: row_responses }
              status = 400
            end
          else
            message = { status: 'All slots full' }
            status = 400
            break
          end
        end
        # p message
        render json: message, status: status


      end

      def correct_version
        id = params[:id]
        res = Net::HTTP.get(URI.parse('http://localhost:9200/locations/location/'+id))
        render json: res['version'], status: 200
      end

      def new_payment
        
      end 

      private

      def post_url(index, type = '_suggest', query = {})
        uri = URI.parse(URI.encode("http://localhost:9200/#{index}/#{type}"))
        query = (query == {}) ? "" : query.to_json
        http = Net::HTTP.new(uri.host, uri.port)
        result = http.post(uri,query)
        body = result.body
        status = result.code
        return body,status
      end
       
    end
  end
end
