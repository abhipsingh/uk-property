module Api
  module V0
    class PropertySearchController < ActionController::Base
      def search
        response = Hash.new
        api = ::PropertyDetailsRepo.new(filtered_params: params)
        result, status = api.filter
        render :json => result, :status => status
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
    end
  end
end
