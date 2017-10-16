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
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.filter
        result = result[:results].sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = [] }
        result = result.each{ |t| t[:photo_urls] = [ process_image(t) ] + t[:photo_urls] }
        #Rails.logger.info(result)
        ## TODO - Confirm this
        # result.first[:breadcrumb] = params[:hash_str].split('_').join(', ')
        #insert_new_search 
        render :json => result, :status => status
      end

      ### curl -XGET 'http://localhost/api/v0/properties/matching/count?hash_str=LIVERPOOL&hash_type=Text&count=true'
      def matching_property_count
        ## hash_str compulsory?
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.matching_property_count
        render :json => result, :status => status
      end
      
      ### TODO: Move to a queue like Sidekiq or Redis
      def insert_new_search
        match_type = params[:match_type]
        listing_type = params[:listing_type]
        match_type ||= 'Perfect'
        listing_type ||= 'Normal'
        match_type = Trackers::Buyer::TYPE_OF_MATCH[match_type.downcase.to_sym]
        listing_type = Trackers::Buyer::LISTING_TYPES[listing_type]
        buyer_id = params[:buyer_id]
        search_hash = params.as_json.except('match_type', 'controller', 'action', 'listing_type', 'buyer_id')
        BuyerSearch.create!(match_type: match_type, listing_type: listing_type, buyer_id: buyer_id, search_hash: search_hash) 
      end

      def save_searches
        saved_flag = true
        messages = [],
        searches = nil
        ## if search hash is not validated or email id is not found then saved flag should be false?
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
        searches, name, email_id = nil, nil, nil
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
      
      #### Details Api for a udprn
      #### curl -XGET 'http://localhost/api/v0/properties/details/10968961'
      def details
        udprn = params[:property_id].to_i
        details_json = PropertyDetails.details(udprn)['_source']
        details_json['description'] = PropertyService.get_description(udprn)
        details_json.delete("hashes")
        details_json.delete("match_type_str")
        details_json.delete("suggest")
        render json: { details: details_json }, status: 200
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
