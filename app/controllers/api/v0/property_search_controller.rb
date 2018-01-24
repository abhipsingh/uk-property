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
        result = result[:results]#.sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = []; t[:percent_completed] = nil }
        result = result.each{ |t| t[:photo_urls] = [ process_image(t) ] + t[:photo_urls] }
        user_valid_for_viewing?(['Buyer', 'Agent', 'Developer'])
        new_result = []
        if false
          new_result = result.map do |each_arr|
            hash = {}
            PropertyService::LOCALITY_ATTRS.each do |attr|
              hash[attr] = each_arr[attr] if each_arr[attr]
            end

            PropertyService::POSTCODE_ATTRS.each do |attr|
              hash[attr] = each_arr[attr] if each_arr[attr]
            end
            hash[:address] = each_arr['address']
            hash[:vanity_url] = each_arr['vanity_url']
            hash[:udprn] = each_arr[:udprn]
            hash[:not_yet_built] = each_arr[:not_yet_built]
            hash[:latitude] = each_arr[:latitude]
            hash[:longitude] = each_arr[:longitude]
            hash
          end
        else
          new_result = result
        end
        render :json => new_result, :status => status
      end

      ### curl -XGET 'http://localhost/api/v0/properties/matching/count?hash_str=LIVERPOOL&hash_type=Text&count=true'
      def matching_property_count
        ## hash_str compulsory?
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.matching_property_count
        render :json => result, :status => status
      end
      
      #### Details Api for a udprn
      #### curl -XGET 'http://localhost/api/v0/properties/details/10968961'
      def details
        user_valid_for_viewing?(['Agent', 'Vendor', 'Buyer'])
        user = @current_user
        udprn = params[:property_id].to_i
        details_json = PropertyDetails.details(udprn)['_source']
        if true
          details_json['photo_urls'] =  process_image(details_json)
          details_json['description'] = PropertyService.get_description(udprn)
          if user.class.to_s == 'Agents::Branches::AssignedAgent'  && details_json[:agent_id].to_i == user.id
            render json: { details: details_json }, status: 200
          else
            details_json['percent_completed'] = nil
            render json: { details: details_json }, status: 200
          end
        else
          hash = {}
          PropertyService::LOCALITY_ATTRS.each do |attr|
            hash[attr] = details_json[attr] if details_json[attr]
          end

          PropertyService::POSTCODE_ATTRS.each do |attr|
            hash[attr] = details_json[attr] if details_json[attr]
          end
          hash[:address] = details_json['address']
          hash[:vanity_url] = details_json['vanity_url']
          hash[:udprn] = details_json[:udprn]
          hash[:not_yet_built] = details_json[:not_yet_built]
          hash[:latitude] = details_json[:latitude]
          hash[:longitude] = details_json[:longitude]
          render json: { details: hash }, status: 200
        end
      end

      ### Returns the breadcrumbs for a given hash
      ### curl -XGET 'http://localhost/api/v0/properties/breadcrumbs'
      def breadcrumbs
        str = params[:hash_str]
        resp_hash = { hash_str: str }
        if params[:hash_str]
          if params[:hash_type].to_s != 'building_type'
            PropertySearchApi.construct_hash_from_hash_str(resp_hash)
            resp_hash.delete(:hash_str)
            breadcrumbs = []
            resp_hash[:county] = MatrixViewCount::COUNTY_MAP[resp_hash[:post_town].upcase] if resp_hash[:county].nil?
            
            ### For London handle it especially
            if resp_hash[:county] == 'London'
              district = resp_hash[:district]
              if district.start_with?('EC')
                resp_hash[:county] = 'Central London'
              elsif district.start_with?('E')
                resp_hash[:county] = 'East London'
              elsif district.start_with?('NW')
                resp_hash[:county] = 'North West London'
              elsif district.start_with?('N')
                resp_hash[:county] = 'North London'
              elsif district.start_with?('SE')
                resp_hash[:county] = 'South East London'
              elsif district.start_with?('SW')
                resp_hash[:county] = 'South West London'
              elsif district.start_with?('WC')
                resp_hash[:county] = 'Central London'
              elsif district.start_with?('W')
                resp_hash[:county] = 'West London'
              end
            end
          else
            PropertySearchApi.construct_hash_from_hash_str(resp_hash)
            udprn = resp_hash[:udprn]
            details = PropertyDetails.details(udprn)[:_source]
            resp_hash = { 
              county: details[:county],
              post_town: details[:post_town],
              dependent_locality: details[:dependent_locality],
              dependent_thoroughfare_description: details[:dependent_thoroughfare_description],
              thoroughfare_description: details[:thoroughfare_description],
              udprn: details[:udprn]
            }
  
            resp_hash[:dependent_locality] = details[:dependent_locality] if details[:dependent_locality]
            resp_hash[:dependent_thoroughfare_description] = details[:dependent_thoroughfare_description] if details[:dependent_thoroughfare_description]
            resp_hash[:thoroughfare_description] = details[:thoroughfare_description] if details[:thoroughfare_description]
            
          end
  
          result = resp_hash.clone
          resp_hash.each do |key, value|
            hash = MatrixViewService.form_hash(resp_hash, key)
            result[(key.to_s + "_hash").to_sym] = hash
          end
          render json: result, status: 200
        else
          render json: { message: 'Hash str cannot be null' }, status: 400
        end
      end

      private

      def user_valid_for_viewing?(klasses=[])
        if !klasses.empty?
          result = nil
          klasses.each do |klass|
            @current_user ||= AuthorizeApiRequest.call(request.headers, klass).result
          end
        end
        @current_user
      end
  
    end

  end
end
