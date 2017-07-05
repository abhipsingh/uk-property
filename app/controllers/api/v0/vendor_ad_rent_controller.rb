module Api
  module V0
    class VendorAdRentController < ActionController::Base

      #### Example curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -H "Content-Type: application/json" "http://localhost/api/v0/ads/rent/availability?addresses%5B%5D=+33&addresses%5B%5D=+Loder+Drive&addresses%5B%5D=+City+Centre&addresses%5B%5D=+HEREFORD&addresses%5B%5D=+Herefordshire&udprn=10966139" 
      #### Parameters {"addresses"=>[" 33", " Loder Drive", " City Centre", " HEREFORD", " Herefordshire"], "udprn"=>"10966139"}
      def ads_availablity
        if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
          score_map = {
            :county => 6,
            :post_town => 5,
            :dependent_locality => 4,
            :dependent_thoroughfare_description => 3,
            :district => 2,
            :unit => 1,
            :sector => 0
          }
          levels = []
          response = {}
          udprn = params[:udprn].to_i
          score_map.each do |key, value|
            response[key.to_s + '_' + 'premium_count'] = nil
            response[key.to_s + '_'  + 'premium_booked'] = nil
            response[key.to_s + '_' + 'featured_count'] = nil
            response[key.to_s + '_' + 'featured_booked'] = nil
          end
          PropertyAd.ads_info_all_address_levels_rent(response, udprn)
          render json: response, status: 200
        else
          render json: { message: 'Authorization failed' }, status: 401
        end
      end

      # curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -H "Content-Type: application/json"  "http://localhost/api/v0/ads/availability/rent/update" -d  '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "udprn":10966139, "locations":{"0":{ "value":"10", "hash":"HEREFORD_City Centre_Loder Drive", "type":"Premium"}}, "months" : 2}'
      def update_availability
        if user_valid_for_viewing?(['Buyer'], params[:udprn].to_i)
          charge = nil
          begin
            # params[:stripeAmount]
            amount = params[:months].to_i * 2 ### 2$ per month
         
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
          client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
          message = {} 
          message[:ads] = []
          status = nil
          locations = params[:locations]
          udprn = params[:udprn].to_i
          details = PropertyDetails.details(udprn)['_source']
          match_type_strs = details['match_type_str']
          new_match_type_strs = []
          ads_count = 0
          Rails.logger.info(locations)
          locations.each do |key, location|
            hash_value = location[:hash]
            type = location[:type]
            value = location[:value].to_i
            Rails.logger.info(location)
            if value > 0
              begin
                ads = PropertyAd::Rent.create(hash_str: hash_value, property_id: udprn.to_i, ad_type: PropertyAd::TYPE_HASH[type])
                message[:ads].push(ads)
                match_type_strs.each do |each_str|
                  if each_str.split('|')[0] == hash_value
                    new_match_type_strs.push(hash_value+'|'+type)
                  else
                    new_match_type_strs.push(each_str)
                  end
                end
                client.update index: Rails.configuration.rent_address_index_name, type: 'address', id: udprn, body: { doc: { match_type_str: new_match_type_strs } }
                ads_count += 1 if ads.id > 0
                message[:ads_count] = ads_count
              rescue Exception => e
                re = Stripe::Refund.create(
                  charge: charge.id,
                  amount: value
                )
                Rails.logger.info(e)
                message = { message: 'Some error occured', rows: [] }
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
        else
          render json: { message: 'Authorization failed' }, status: 401
        end
      end

      def correct_version
        id = params[:id]
        res = Net::HTTP.get(URI.parse('http://localhost:9200/locations/location/'+id))
        render json: res['version'], status: 200
      end

      def new_payment
        
      end 

      private

      def post_url(index, type = '_suggest', query = {}, url="http://localhost:9200")
        uri = URI.parse(URI.encode("#{url}/#{index}/#{type}"))
        query = (query == {}) ? "" : query.to_json
        http = Net::HTTP.new(uri.host, uri.port)
        result = http.post(uri,query)
        body = result.body
        status = result.code
        return body,status
      end

      def user_valid_for_viewing?(user_types, udprn)
        user_types.any? do |user_type|
          result = authenticate_request(user_type)
          if user_type == 'Agent'
            details = PropertyDetails.details(udprn)
            details_completed = details['_source']['details_completed']
            details_completed ||= false
            result = result && details_completed
          end
          result
        end
      end

      def authenticate_request(klass='Agent')
        result = AuthorizeApiRequest.call(request.headers, klass).result
        !result.nil?
      end
    end
  end
end