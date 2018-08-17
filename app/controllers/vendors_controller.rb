class VendorsController < ApplicationController
  around_action :authenticate_vendor, only: [ :show_vendor_availability, :add_unavailable_slot ]

  def valuations
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    vendor_api.calculate_valuations
    render json: valuation_info
  end

  ### List of properties for the vendor and the agent confirmation status
  ### curl -XGET -H "Authorization:  izxbsz373hdxsnsz2" 'http://localhost/list/inviting/agents/properties'
  def list_inviting_agents_properties
    agents = []
    user_valid_for_viewing?(['Vendor', 'Agent'], nil)
    if @current_user
      InvitedVendor.where(email: @current_user.email, accepted: nil).select([:created_at, :udprn, :agent_id, :id]).each do |invited_vendor|
        result_hash = {}
        result_hash[:created_at] = invited_vendor.created_at
        result_hash[:udprn] = invited_vendor.udprn
        udprn = invited_vendor.udprn
        details = PropertyDetails.details(udprn)[:_source]
        result_hash[:address] = details[:address]
        result_hash[:agent_id] = invited_vendor.agent_id
        result_hash[:invitation_id] = invited_vendor.id
        agent = Agents::Branches::AssignedAgent.where(id: invited_vendor.agent_id).last
        if agent
          branch = agent.branch
          result_hash[:agent_email] = agent.email
          result_hash[:agent_name] = agent.first_name + ' ' + agent.last_name
          result_hash[:agent_image_url] = agent.image_url
          result_hash[:branch_image_url] = branch.image_url
          result_hash[:branch_address] = branch.address
          result_hash[:branch_website] = branch.website
          result_hash[:branch_phone_number] = branch.phone_number
          result_hash[:title] = agent.title
          result_hash[:mobile_phone_number] = agent.mobile
          result_hash[:office_phone_number] = agent.office_phone_number
        end
        agents.push(result_hash)
      end
      render json: agents, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end


  ##### To emulate this we need some sold properties of agents and some changes
  ##### to the valuations in those sold properties. To have those, we can issue
  ##### the following curl requests

  ##### Three udprns have been marked to be shown as sold
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "sold", "message" : "\{ \"final_price\" : 300000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "sold", "message" : "\{ \"final_price\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  #  curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "sold", "message" : "\{ \"final_price\" : 360000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  #### For each of the udprn [10976765, 10977419, 54042234] events concerning valuation change are selected
  # ######## For 10976765
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 280000, \"current_valuation\" : 285000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 285000, \"current_valuation\" : 289000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 289000, \"current_valuation\" : 295000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10976765', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 295000, \"current_valuation\" : 300000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # ######## For 10977419
  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 335000, \"current_valuation\" : 320000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 320000, \"current_valuation\" : 318000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '10977419', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 318000, \"current_valuation\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # ####### For 54042234

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 350000, \"current_valuation\" : 340000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  # curl -XPOST -H "Content-Type: application/json" 'http://localhost/events/new' -d '{"agent_id" : 1234, "udprn" : '54042234', "event" : "valuation_change", "message" : "\{ \"previous_valuation\" : 340000, \"current_valuation\" : 360000 \}", "type_of_match" : "perfect", "buyer_id" : 1, "property_status_type" : "Green" }'

  def quotes
    property_id = params[:udprn]
    vendor_api = VendorApi.new(property_id)
    quotes = vendor_api.calculate_quotes(branch_ids.split(',').map(&:to_i))
    render json: quotes
  end

  ### Quicklinks of the properties that the vendor holds
  # curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/:vendor_id'
  # curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/1'
  def properties
    # vendor = Vendor.find(params[:vendor_id])
    search_params = { vendor_id: params[:vendor_id].to_i, results_per_page: 150 }
    search_params[:p] = params[:p].to_i if params[:p]
    pd = PropertySearchApi.new(filtered_params: search_params )
    pd.query[:size] = 1000
    results, status = pd.filter
    results[:results].each { |e| e[:address] = PropertyDetails.address(e) }
    response = results[:results].map { |e| e.slice(:udprn, :address)  }
    response = response.sort_by{ |t| t[:address] }
    #Rails.logger.info "sending response for vendor properties -> #{response.inspect}"
    render json: response, status: status
  end

  ### Details of a specific property that a vendor holds
  ### curl -XGET -H "Content-Type: application/json" 'http://localhost/vendors/properties/details/1?udprn=10966139'
  def property_details
    details = VendorApi.new(params[:udprn].to_i, nil, params[:vendor_id].to_i).property_details
    render json: details, status: 200
  end

  ### Edit vendor details
  ### curl -XPOST -H "Content-Type: application/json"  'http://localhost/vendors/86/edit' -d '{ "vendor" : { "name" : "Jackie Chan", "email" : "jackie.bing@friends.com", "mobile" : "9873628232", "password" : "1234567890", "image_url": "some_random_url" } }'
  def edit
    vendor_params = params[:vendor]
    vendor = Vendor.where(id: params[:id].to_i).first
    if vendor
      vendor.first_name = vendor_params[:first_name] if vendor_params[:first_name]
      vendor.last_name = vendor_params[:last_name] if vendor_params[:last_name]
      vendor.name = vendor_params[:first_name] + vendor_params[:last_name] if vendor_params[:first_name] && params[:last_name]
      vendor.mobile = vendor_params[:mobile] if vendor_params[:mobile]
      vendor.password = vendor_params[:password] if vendor_params[:password]
      vendor.image_url = vendor_params[:image_url] if vendor_params[:image_url]
      vendor.working_hours = vendor_params[:working_hours] if vendor_params[:working_hours]
      update_hash = { vendor_id: params[:id].to_i }
      ### TODO: Update attributes in all the properties
      if vendor.save
        VendorUpdateWorker.new.perform(vendor.id)
        render json: { message: 'Vendor successfully updated', details:  vendor.as_json }, status: 200
      else
        render json: { message: 'Vendor not able to update' }, status: 400
      end
    else
      render json: { message: 'Vendor not found' }, status: 404
    end
  end

  ### After the agent who won the lead, surveyed the property, submitted the property details
  ### and the email which was consequently sent to the vendor. This is the api called by the email
  ### link to judge the vendor's response as affirmative or negative
  ### curl  -XGET -H "Authorization: Random header" 'http://localhost/vendors/:udprn/:agent_id/lead/details/verify/:verified'
  ### curl  -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxMjM0LCJleHAiOjE0OTY2NzAwNzV9.QZKmD9Jrt_TuJH9JvA-QTr5xY77tNdDt6bF2vzK8kW0"  'http://localhost/vendors/12843737/1234/lead/details/verify/true'
  def verify_details_submitted_from_agent_following_lead
    if user_valid_for_viewing?(['Vendor'], params[:udprn].to_i)
      verified = params[:verified] == 'true' ? true : false
      vendor_id = @current_user.id
      agent_id = params[:agent_id].to_i
      if verified
        PropertyService.new(params[:udprn].to_i).attach_assigned_agent(agent_id)
        render json: { message: 'The agent has been chosen as your assigned agent' }, status: 200
      else
        ### TODO: Report to the admin
        render json: { message: 'The incident will reported to admin' }, status: 400
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### When a vendor verifies that an agent is the not the true owner of the property
  ### curl -XPOST -H "Authorization: eyJ0eXAiOiJK" 'http://localhost/vendors/unverify/:udprn/:agent_id'
  def unverify_agent_from_a_property ### Invited by the vendor
    if user_valid_for_viewing?(['Vendor'], params[:udprn].to_i)
      udprn = params[:udprn].to_i
      agent_id = params[:agent_id].to_i
      vendor_id = @current_user.id
  
      #### Transfer the enquiries
      Event.where(agent_id: agent_id, udprn: udprn).update_all(agent_id: nil)
      update_hash = { agent_id: nil, claimed_at: nil, claimed_by: nil, vendor_id: nil, beds: nil, baths: nil, receptions: nil, property_type: nil, property_status_type: nil }

      #### Destroy the f&f lead
      Agents::Branches::AssignedAgents::Lead.where(property_id: params[:udprn].to_i, agent_id: agent_id, owned_property: true).last.destroy
      PropertyService.new(udprn).update_details(update_hash)

      render json: { message: "The property has been removed from agents and vendors properties" }, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### List the properties and agents for this vendor
  ### curl -XGET -H "Authorization: eyJ0eXAiOiJK" 'http://localhost/vendors/verify/inviting/agents'
  def list_inviting_agent_and_property
    if user_valid_for_viewing?(['Vendor'], params[:udprn].to_i)
    #if true
      @current_user = Vendor.find(533)
      vendor_id = @current_user.id
      invited_vendors = InvitedVendor.where(email: @current_user.email, source: Vendor::INVITED_FROM_CONST[:family]).select([:agent_id, :udprn])
      udprns = invited_vendors.map(&:udprn)
      bulk_details = PropertyService.bulk_details(udprns)
      response = []

      bulk_details.each_with_index do |detail, index|
        detail[:address] = PropertyDetails.address(detail)
        response_hash = {}
        response_hash[:udprn] = detail[:udprn]
        response_hash[:address] = detail[:address]
        agent_fields = [:agent_id, :assigned_agent_first_name, :assigned_agent_last_name, :assigned_agent_email, :assigned_agent_mobile,
                        :assigned_agent_office_number, :assigned_agent_image_url, :assigned_agent_branch_name, :assigned_agent_branch_number,
                        :assigned_agent_branch_address, :assigned_agent_branch_website, :assigned_agent_branch_logo]
        property_attrs = [:beds, :baths, :receptions, :property_type, :property_status_type ]
        agent_fields.each {|field| response_hash[field] = detail[field] }
        property_attrs.each {|field| response_hash[field] = detail[field] }
        response.push(response_hash)
      end

      render json: response, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### curl -XGET  'http://localhost/non/crawled/properties?udprn=1'
  def non_crawled_properties
    google_st_view_images = GoogleStViewImage.where(crawled: false)
                                             .where("udprn > ?", params[:udprn].to_i)
                                             .select([:udprn, :address])
                                             .order('udprn')
                                             .limit(40)
    Rails.logger.info(google_st_view_images.map(&:udprn))
    render json: google_st_view_images, status: 200
  end

  ### curl -XPOST 'http://localhost/non/crawled/properties?udprns=1163949,1163948'
  def post_non_crawled_properties
    udprns = params[:udprns].split(',').map(&:to_i) if params[:udprns]
    udprns ||= params[:udprn].split(',').map(&:to_i)
    google_st_view_images = GoogleStViewImage.where(udprn: udprns).delete_all
    render json: 'SUCCESS', status: 200
  end

  ### Shows availability of the vendor
  ### curl -XGET -H "Authorization: abxsbsk21w1xa" 'http://localhost/vendors/availability'
  def show_vendor_availability
    start_time = params[:start_time]
    end_time = params[:end_time]
    meetings = VendorCalendarUnavailability.where(vendor_id: @current_user.id).where("((end_time > ?) OR (end_time < ?)) AND ((start_time > ?) OR (start_time < ?))", start_time, end_time, start_time, end_time)
    render json: { unavailable_times: meetings }, status: 200
  end

  ### Add unavailablity slot for the vendor
  ### curl -XPUT -H "Authorization: abxsbsk21w1xa" 'http://localhost/vendors/add/unavailability' -d '{ "start_time" : "2017-01-10 14:00:06 +00:00", "end_time" : "2017-02-11 15:00:07 +00:00" }'
  def add_unavailable_slot
    vendor = @current_user
    start_time = Time.parse(params[:start_time])
    end_time = Time.parse(params[:end_time])
    meeting_details = nil
    if start_time > Time.now && end_time > Time.now && start_time < end_time
      meeting_details = VendorCalendarUnavailability.create!(start_time: start_time, end_time: end_time, vendor_id: @current_user.id)
    end
    render json: { details: meeting_details }, status: 200
  end

  private

  def user_valid_for_viewing?(user_types, udprn)
    user_types.any? do |user_type|
      @current_user ||= authenticate_request(user_type).result
      !@current_user.nil?
    end
  end

  def authenticate_vendor
    if user_valid_for_viewing?(['Vendor'], nil)
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def authenticate_request(klass='Agent')
    AuthorizeApiRequest.call(request.headers, klass)
  end
end

