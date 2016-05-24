### Base controller
class PropertiesController < ActionController::Base

  def edit
    udprn = params[:udprn]
    @udprn = udprn
    property = JSON.parse(Net::HTTP.get(URI.parse("http://localhost:9200/addresses/address/#{udprn}")))
    property = property['_source'] if property.has_key?('_source')
    @building_unit = ''
    @building_unit += property['building_number'] if property.has_key?('building_number')
    @building_unit += ', ' + property['sub_building_name'] if property.has_key?('sub_building_name')
    @building_unit += ', ' + property['building_name'] if property.has_key?('building_name')
    @postcode = property['postcode']
    @historical_details = PropertyHistoricalDetail.where(udprn: udprn).select([:price, :date])
    @address = PropertyDetails.address(property)
    @map_view_url = PropertyDetails.get_map_view_iframe_url(property)
    vendor_api = VendorApi.new(udprn)
    @valuations = vendor_api.calculate_valuations
    @quotes = vendor_api.calculate_quotes
    render 'edit'
  end

  def short_form
    @udprn = params[:udprn]
    render 'short_form'
  end

  def claim_property
    if params[:udprn]
      @detail = TempPropertyDetail.create(details: short_form_params, udprn: params[:udprn]) if params[:udprn]
      @udprn = params[:udprn]
      @user = params[:user]
      @detail_id = params[:detail_id]
      render 'short_contact_form'
    end
  end

  def complete_profile
    p params
    @user = PropertyUser.from_omniauth(params)
    detail_id = params[:property_detail].to_i
    @user.save
    @temp = TempPropertyDetail.where(id: detail_id).first
    if @user.profile_type == 'Vendor'
      @temp.vendor_id = @user.id
    else
      @temp.agent_id = @temp['details']['branch']
    end
    @temp.user_id = @user.id
    @temp.save
    render 'complete_signup'
  end

  def signup_after_confirmation
    user = params[:user_id]
    detail = params[:id]
    @detail = TempPropertyDetail.where(id: detail).first
    @property_user = PropertyUser.where(id: user).last
    @email = @property_user.email
    resource = @property_user
    render 'signup_after_confirmation'
  end

  def property_status
    user = PropertyUser.find_by_email(params['property_user']['email'])
    if user && user.valid_password?(params['property_user']['password'])
      temp_detail = TempPropertyDetail.where('vendor_id = ? OR agent_id = ?', user.id, user.id).last
      if temp_detail
        @property_status = temp_detail.details['property_status']
        @property_id = temp_detail.id
        render 'property_status'
      end
    end
  end


  def custom_agent_service
    if params['property_status'] == 'Green' && params['property_status_value'] != 'Green'
      @property_id = params['property_id']
      temp_detail = TempPropertyDetail.where(id: @property_id).last
      @agent_name = Agents::Branch.where(id: temp_detail.details['branch'].to_i).last.name rescue ''
      @agent_id = Agents::Branch.where(id: temp_detail.details['branch'].to_i).last.id rescue ''
      render 'menu_form'
    end
  end

  def final_quotes
    p params
    agent_services = params.except(:controller, :action, :property_id, :agent_id)
    property_id = params[:property_id]
    temp_property = TempPropertyDetail.where(id: property_id.to_i).last
    temp_property.agent_services = agent_services
    temp_property.save
    @udprn = temp_property.udprn
    render 'finish'
  end

  private

  def short_form_params
    params.permit(:agent, :branch, :property_status, :receptions, :beds, :baths, :property_type, :dream_price, :udprn)
  end



end
