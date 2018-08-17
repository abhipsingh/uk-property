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
      include MatrixViewHelper

      around_action :authenticate_all, only: [ :search, :details ]

      def search
        api = ::PropertySearchApi.new(filtered_params: params)
        result, status = api.filter
        result = result[:results]#.sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = []; t[:percent_completed] = nil }
        result = result.each{ |t| t[:photo_urls] = [ process_image(t) ] + t[:photo_urls] }
        #user_valid_for_viewing?(['Buyer', 'Agent', 'Developer'])
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

      def search_fr
        api = ::Fr::PropertySearchApi.new(filtered_params: params)
        result, status = api.filter
        result = result[:results]#.sort_by{|t| t[:score]}.reverse
        result = result.each{|t| t[:photo_urls] = []; t[:percent_completed] = nil }
        result = result.each{ |t| t[:photo_urls] = [ process_image_fr(t) ] + t[:photo_urls] }
        #user_valid_for_viewing?(['Buyer', 'Agent', 'Developer'])
        new_result = []
        if false
          new_result = result.map do |each_arr|
            hash = {}
            PropertyService::LOCALITY_ATTRS.each do |attr|
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
      ### Matching property count for particular set of filters
      ### curl -XGET 'http://localhost/api/v0/properties/matching/count?hash_str=LIVERPOOL&hash_type=Text&count=true'
      def matching_property_count
        ## hash_str compulsory?
        api = ::PropertySearchApi.new(filtered_params: params)
        count, status = api.matching_property_count
        render :json => count, :status => status
      end

      ### Return street and locality hash for any udprn
      ### curl -XGET 'http://localhost/property/hash/10968961'
      def udprn_street_locality_hash
        udprn = params[:udprn]
        details = PropertyDetails.details(udprn.to_i)[:_source]
        locality_hash = Events::Track.locality_hash(details)
        street_hash = Events::Track.street_hash(details)
        street_hash_type = nil

        if details[:thoroughfare_description]
          street_hash_type = :thoroughfare_description
        elsif details[:dependent_thoroughfare_description]
          street_hash_type = :dependent_thoroughfare_description
        end

        render json: { locality_hash: locality_hash, street_hash: street_hash, street_hash_type: street_hash_type, locality_hash_type: :dependent_locality }, status: 200
      end

      #### Details Api for a udprn
      #### curl -XGET 'http://localhost/api/v0/properties/details/10968961'
      def details
        user = @current_user
        udprn = params[:property_id].to_i
        details_json = PropertyDetails.details(udprn)[:_source]
        details_json[:locality_hash] = Events::Track.locality_hash(details_json)
        details_json[:street_hash] = Events::Track.street_hash(details_json)
        details_json[:county_hash] = MatrixViewService.form_hash(details_json, :county)
        details_json[:post_town_hash] = MatrixViewService.form_hash(details_json, :post_town)
        if true
          photo_urls = process_image(details_json)
          !photo_urls.is_a?(Array) ? details_json['photo_urls'] = [ photo_urls ] : details_json['photo_urls'] = photo_urls
          details_json['description'] = PropertyService.get_description(udprn)
          if user && ((user.class.to_s == 'Agents::Branches::AssignedAgent'  && details_json[:agent_id].to_i == user.id) || (user.id == details_json[:vendor_id].to_i && user.class.to_s == 'Vendor' ))
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
            mvs = MatrixViewService.new(hash_str: params[:hash_str])
            resp_hash[:type] = mvs.level
            output_str = calculate_formatted_string(resp_hash, resp_hash[:type].to_sym)
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
            resp_hash[:output_str] = output_str
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
              udprn: details[:udprn],
              district: details[:district],
              sector: details[:sector],
              unit: details[:unit],
              output_str: details[:address]
            }

          end
  
          result = resp_hash.clone
          resp_hash.each do |key, value|
            if key != :output_str && key != :type
              hash = MatrixViewService.form_hash(resp_hash, key)
              result[(key.to_s + "_hash").to_sym] = hash
            end
          end
          render json: result, status: 200
        else
          render json: { message: 'Hash str cannot be null' }, status: 400
        end
      end

      ### Randomise the property ads for featured properties
      ### curl -XGET 'http://localhost/api/v0/randomise/ads/property'
      def randomise_property_ad
        udprns = PropertyAd.where(ad_type: PropertyAd::TYPE_HASH['Featured']).order("random()").limit(5).pluck(:property_id)
        result = PropertySearchApi.new(filtered_params: {}).fetch_details_from_udprns(udprns)
        result = result.each{|t| t[:photo_urls] = []; t[:percent_completed] = nil }
        result = result.each{ |t| t[:photo_urls] = [ process_image(t) ] + t[:photo_urls] }
        render json: { random_ad_properties: result }, status: 200
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

      def authenticate_all
        if user_valid_for_viewing?(['Vendor', 'Agent', 'Developer'])
          yield
        else
          yield
        end
      end
  
    end

  end
end

