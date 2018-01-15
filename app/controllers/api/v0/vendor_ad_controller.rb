module Api
  module V0

    class VendorAdController < ActionController::Base

      include CacheHelper
      before_filter :set_headers
      #### Example curl -XGET  -H "Content-Type: application/json" "http://localhost/api/v0/ads/availability?udprn=10966139&property_status_type=Sale" 
      #### Parameters {"addresses"=>[" 33", " Loder Drive", " City Centre", " HEREFORD", " Herefordshire"], "udprn"=>"10966139", "property_status_type" => 'Rent'}
      def ads_availablity
        if user_valid_for_viewing?(['Agent', 'Vendor'], params[:udprn].to_i)
      #  if true
            score_map = {
              :county => 7,
              :post_town => 6,
              :dependent_locality => 5,
              :dependent_thoroughfare_description => 4,
              :thoroughfare_description => 3,
              :district => 2,
              :unit => 1,
              :sector => 0,
              :area => -1
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
            property_for = params[:property_status_type]
            property_for ||= 'Sale'
            PropertyAd.ads_info_all_address_levels(response, udprn, property_for)
            render json: response, status: 200
        else
          render json: { message: 'Authorization failed' }, status: 401
        end
      end
      
      ### TODO: Incorporate ads, months and expiration accordingly
      # curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -H "Content-Type: application/json"  "http://localhost/api/v0/ads/availability/update" -d  '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "udprn":10966139, "locations":{"0":{ "value":"10", "hash":"HEREFORD_City Centre_Loder Drive", "type":"Premium"}}, "months" : 2}'
      def update_availability
        if user_valid_for_viewing?(['Vendor', 'Agent'], params[:udprn].to_i)
          charge = nil
         
          # Create the customer in Stripe
          customer = Stripe::Customer.create(
            email: params[:stripeEmail],
            card: params[:stripeToken]
          )
       
          locations = params[:locations]
          client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
          message = {} 
          message[:ads] = []
          status = nil
          udprn = params[:udprn].to_i
          details = PropertyDetails.details(udprn)['_source']
          ads_count = 0
          service = nil
          details['property_status_type'] != 'Rent' ? service = 1 : service = 2
          #Rails.logger.info(locations)
          chargeable_amount = 0
          locations.each do |key, location|
            hash_value = location[:hash]
            type = location[:type]
            value = (( PropertyAd::PRICE[location[:type]])*100*location[:months].to_i)
            num_months = location[:months].to_i
            expiry_at = (num_months*30).days.from_now.to_time
          #  Rails.logger.info(location)
            if PropertyAd.where(hash_str: hash_value, ad_type: PropertyAd::TYPE_HASH[type], service: service).count < PropertyAd::MAX_ADS_HASH[type]
              ads = PropertyAd.create(hash_str: hash_value, property_id: udprn.to_i, ad_type: PropertyAd::TYPE_HASH[type], service: service, expiry_at: expiry_at)

              ### Create a log for future reference
              AdPaymentHistory.create!(hash_str: hash_value, udprn: udprn.to_i, type_of_ad: PropertyAd::TYPE_HASH[type], service: service, months: location[:months].to_i)

              message[:ads].push({hash: hash_value, type: type, booked: true, expiry_at: expiry_at.to_s, amount: value, message: "Booked slot successfully"})
              chargeable_amount += value
              ads_count += 1 if ads.id > 0
              message[:ads_count] = ads_count
            else
              message[:ads].push({hash: hash_value, type: type, booked: false, expiry_at: nil, amount: nil, message: 'Slot is full'})
            end
          end

          begin
            charge = Stripe::Charge.create(
              customer: customer.id,
              amount: chargeable_amount,
              description: "Ads amount charged for #{udprn}, #{service}, #{Time.now.to_s}",
              currency: 'GBP'
            )
          rescue Stripe::CardError => e
            booked_ads = message[:ads].select{|t| t[:booked] == true }
            booked_ads.each do |t|
              t[:booked] = false
              t[:expiry_at] = nil
              t[:amount] = nil
              t[:message] = "StripeCardError: #{e.message}. Unknown Stripe error"
            end
            PropertyAd.where(property_id: udprn.to_i, service: service).where("created_at > ?", 1.hour.ago).destroy_all
          end
          # p message
          # Rails.logger.info(message)
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

      def set_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Expose-Headers'] = 'ETag'
        headers['Access-Control-Allow-Methods'] = 'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD'
        headers['Access-Control-Allow-Headers'] = '*,x-requested-with,Content-Type,If-Modified-Since,If-None-Match'
        headers['Access-Control-Max-Age'] = '86400'
      end
    end
  end

end

