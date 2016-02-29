module Api
  module V0
    class VendorAdController < ActionController::Base
      def ads_availablity
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
            text_val = init_values[(len - 1 - count), (len - 1)].join(' ')
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
          new_and_filter = and_filter.deep_dup
          hash = value[0]["options"].first["payload"]["hash"]
          type = value[0]["options"].first["payload"]["type"]
          new_and_filter[:and][:filters].push( { term: { hashes: hash } } )
          new_and_filter[:and][:filters].push( { term: { type_value: type } } )
          new_and_filter[:and]['_name'] = key
          filter_query[:filter][:or][:filters].push( new_and_filter )
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
        final_response[:availability_count] = response
        if ads_query[:filter][:or][:filters].empty?
          final_response['ads_availablity'] = {}
        else
          response, code = post_url('property_ads', '_search', ads_query)
          response = JSON.parse(response)['hits']['hits']
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
        client = Elasticsearch::Client.new
        id = params[:id]
        type = params[:type]
        version = params[:version].to_i
        value = params[:value].to_i
        users = params[:users]
        premium_buyers = params[:premium_buyers].split(',')
        featured_buyers = params[:featured_buyers].split(',')
        if value > 0
          if type == 'featured_count'
            featured_buyers |= [users]
          else
            premium_buyers |= [users]
          end
          begin
            response = client.update index: 'locations', type: 'location', id: id, version: version, 
                                     body: { doc: { type => (value - 1), version: (version + 1),
                                             featured_buyers: featured_buyers, premium_buyers: premium_buyers } }
            new_ad = {
              location_id: id,
              property_id: users,
              type_of_ad: type,
              entity_id: users,
              created_at: 30.days.from_now.to_date.to_s
            }
            response = client.index index: 'property_ads', type: 'property_ad', body: new_ad
            expriry_date = 30.days.from_now.to_date.to_s
            render json: { message: 'Successful', expiry_date: expriry_date }, status: 200
          rescue Elasticsearch::Transport::Transport::Errors::Conflict => e
            render json: { message: 'Conflict' }, status: 400
          rescue Exception => e
            Rails.logger.info(e)
            render json: { message: 'Some error occured' }, status: 400
          end
        else
          render json: { status: 'All slots full' }, status: 400
        end
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