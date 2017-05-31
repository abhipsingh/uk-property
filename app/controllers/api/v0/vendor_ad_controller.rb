module Api
  module V0
    class VendorAdController < ActionController::Base

      #### Example curl -XGET "/api/v0/ads/availability?addresses%5B%5D=+33&addresses%5B%5D=+Loder+Drive&addresses%5B%5D=+City+Centre&addresses%5B%5D=+HEREFORD&addresses%5B%5D=+Herefordshire&udprn=10966139"
      #### Parameters {"addresses"=>[" 33", " Loder Drive", " City Centre", " HEREFORD", " Herefordshire"], "udprn"=>"10966139"}
      def ads_availablity
        score_map = {
          :county => 6,
          :post_town => 5,
          :dependent_locality => 4,
          :dependent_thoroughfare_description => 3
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
        PropertyAd.ads_info_all_address_levels(response, udprn)
        render json: response, status: 200
      end

      # curl -XPOST "/api/v0/ads/availability/update" -d  '{\"stripeEmail\"=>\"abhiuec@gmail.com\", \"stripeToken\"=>\"tok_19WlE9AKL3KAwfPBkWwgTpqt\", \"udprn\"=>\"10966139\", \"locations\"=>{\"0\"=>{\"value\"=>\"10\", \"hash\"=>\"HEREFORD_City Centre_Loder Drive\", \"type\"=>\"Premium\"}}}'
      def update_availability
        charge = nil
        begin
          # params[:stripeAmount]
          amount = params[:stripeAmount].to_i * 100
       
          # Create the customer in Stripe
          customer = Stripe::Customer.create(
            email: params[:stripeEmail],
            card: params[:stripeToken]
          )
       
          # Create the charge using the customer data returned by Stripe API
          charge = Stripe::Charge.create(
            customer: customer.id,
            amount: 100,
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
              ads = PropertyAd.create(hash_str: hash_value, property_id: udprn.to_i, ad_type: PropertyAd::TYPE_HASH[type])
              message[:ads].push(ads)
              match_type_strs.each do |each_str|
                if each_str.split('|')[0] == hash_value
                  new_match_type_strs.push(hash_value+'|'+type)
                else
                  new_match_type_strs.push(each_str)
                end
              end
              client.update index: Rails.configuration.address_index_name, type: 'address', id: udprn, body: { doc: { match_type_str: new_match_type_strs } }
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
    end
  end
end
