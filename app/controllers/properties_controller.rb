### Base controller
class PropertiesController < ActionController::Base

  def edit
    udprn = params[:udprn]
    @udprn = udprn
    property = PropertyDetails.details(udprn)['_source']
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
    @detail = TempPropertyDetail.create(details: short_form_params, udprn: params[:udprn]) if params[:udprn]
    @udprn = params[:udprn]
    @user = params[:user]
    @detail_id = params[:detail_id]
    render 'short_contact_form'
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
      @temp.agent_id = @temp['details']['branch'].to_i
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
      Rails.logger.info("INFOO_#{user.id}")
      temp_detail = TempPropertyDetail.where('user_id = ?', user.id).last
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
    agent_services = params.except(:controller, :action, :property_id, :agent_id)
    property_id = params[:property_id]
    temp_property = TempPropertyDetail.where(id: property_id.to_i).last
    temp_property.agent_services = agent_services
    temp_property.save
    @udprn = temp_property.udprn
    render 'finish'
  end

  ### When a request is made to fetch the historic pricing details for a udprn
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/prices/10966139'
  def historic_pricing
    details = PropertyDetails.historic_pricing_details(params[:udprn].to_i)
    render json: details, status: 200
  end

  ### This route provides all the details of the recent enquiries made by the users on this property
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/enquiries/property/10966139'
  def enquiries
    enquiries = Trackers::Buyer.new.property_enquiries(params[:udprn].to_i)
    render json: enquiries, status: 200
  end

  #### The following actions are specific for data related to buyer interest tables and pie charts
  #### From interest awareness table, this action gives the data regarding buyer activity related to
  #### the property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/interest/10966139'
  def interest_info
    interest_info = Trackers::Buyer.new.interest_info(params[:udprn].to_i)
    render json: interest_info, status: 200
  end

  #### From supply table, this action gives the data regarding how many properties are similar to
  #### their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/supply/10966139'
  def supply_info
    supply_info = Trackers::Buyer.new.supply_info(params[:udprn].to_i)
    render json: supply_info, status: 200
  end

  #### From supply table, this action gives the data regarding how many buyers are searching for properties
  #### similar to their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/demand/10966139'
  def demand_info
    demand_info = Trackers::Buyer.new.demand_info(params[:udprn].to_i)
    render json: demand_info, status: 200
  end

  #### From supply table, this action gives the data regarding how many buyers are searching for properties
  #### similar to their property.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/buyer/intent/10966139'
  def buyer_intent_info
    buyer_intent_info = Trackers::Buyer.new.buyer_intent_info(params[:udprn].to_i)
    render json: buyer_intent_info, status: 200
  end

  #### For all the pie charts concerning the profile of the buyer, this action can be used.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/buyer/profile/stats/10966139'
  def buyer_profile_stats
    buyer_profile_stats = Trackers::Buyer.new.buyer_profile_stats(params[:udprn].to_i)
    render json: buyer_profile_stats, status: 200
  end

  #### For all the pie charts concerning the profile of the buyer, this action can be used.
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/agent/stage/rating/stats/10966139?agent_id=1234'
  def agent_stage_and_rating_stats
    quote = Agents::Branches::AssignedAgents::Quote.where(agent_id: params[:agent_id].to_i).where(property_id: params[:udprn].to_i).last
    if quote && quote.status == 1
      response = Trackers::Buyer.new.agent_stage_and_rating_stats(params[:udprn].to_i)
      status = 200
    else
      response = { message: " You're not subscribed to this property " }
      status = 400
    end
    render json: response, status: status
  end

  #### Ranking stats for the given property
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/ranking/stats/10966139'
  def ranking_stats
    ranking_info = Trackers::Buyer.new.ranking_stats(params[:udprn].to_i)
    render json: ranking_info, status: status
  end

  #### Ranking stats for the given property
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1'
  #### Four filters can be applied
  #### type_of_enquiry
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?enquiry_type=requested_message'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?type_of_match=Perfect'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?property_status_type=Green'
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/property/history/enquiries/1?search_str=Jacqueline'
  def history_enquiries
    enquiry_type = params[:enquiry_type]
    type_of_match = params[:type_of_match].downcase.to_sym if params[:type_of_match]
    property_status_type = params[:property_status_type]
    search_str = params[:search_str]

    ranking_info = Trackers::Buyer.new.history_enquiries(params[:buyer_id].to_i, enquiry_type, type_of_match, property_status_type, search_str)
    render json: ranking_info, status: status
  end

  private

  def short_form_params
    params.permit(:agent, :branch, :property_status, :receptions, :beds, :baths, :property_type, :dream_price, :udprn)
  end



end
