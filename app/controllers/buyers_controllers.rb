### Base controller
class BuyersController < ActionController::Base
  around_action :authenticate_buyer, only: [ :tracking_history, :process_premium_payment, :tracking_stats, :tracking_details, :edit_tracking,
                                             :subscribe_premium_service ]

	#### When basic details of the buyer is saved
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/7/edit' -d '{ "status" : "Green", "buying_status" : "First time buyer", "budget_from" : 5000, "budget_to": 100000, "chain_free" : false, "funding_status" : "Mortgage approved", "biggest_problem" : "Money" , "rent_requirement": { "min_beds" :3, "max_beds":4, "min_baths" : 1, "max_baths" : 2, "min_receptions":1, "max_receptions":3, "locations" : "bla bla bla"}  }'
  #### Another example of editing name, mobile and image_url
  #### curl -XPOST -H "Content-Type: application/json"  'http://localhost/buyers/43/edit' -d '{ "name" : "Jack Bing", "image_url" : "random_image_url", "mobile" : "9876543321" }'
	def edit_basic_details
		buyer = PropertyBuyer.find(params[:id])
		buying_status = PropertyBuyer::BUYING_STATUS_HASH[params[:buying_status]] if params[:buying_status]
    rent_requirement_params = params[:rent_requirement]
		budget_from = params[:budget_from].to_i if params[:budget_from]
		budget_to = params[:budget_to].to_i if params[:budget_to]
		status = PropertyBuyer::STATUS_HASH[params[:status].downcase.to_sym] if params[:status]
		funding_status = PropertyBuyer::FUNDING_STATUS_HASH[params[:funding]] if params[:funding]
		biggest_problem = params[:biggest_problems] if params[:biggest_problems]
		chain_free = params[:chain_free] if !params[:chain_free].nil?
		buyer.buying_status = buying_status if buying_status
		buyer.budget_from = budget_from if budget_from
		buyer.budget_to = budget_to if budget_to

    ### Record changes in buyer status
    if status
      BuyerStatusChange.create!(buyer_id: buyer.id, prev_status: buyer.status, new_status: status, date: Date.today)
		  buyer.status = status
    end

		buyer.funding = funding_status if funding_status
		buyer.biggest_problems = biggest_problem if biggest_problem
		buyer.chain_free = chain_free unless chain_free.nil?
		buyer.mobile = params[:mobile] if params[:mobile]
		buyer.image_url = params[:image_url] if params[:image_url]
		buyer.name = params[:name] if params[:name]
		buyer.first_name = params[:first_name] if params[:first_name]
		buyer.last_name = params[:last_name] if params[:last_name]
		buyer.property_types = params[:property_types] if params[:property_types]
		buyer.locations = params[:locations] if params[:locations] && params[:locations].is_a?(Array)
		buyer.min_beds = params[:min_beds] if params[:min_beds]
		buyer.max_beds = params[:max_beds] if params[:max_beds]
		buyer.min_baths = params[:min_baths] if params[:min_baths]
		buyer.max_baths = params[:max_baths] if params[:max_baths]
		buyer.min_receptions = params[:min_receptions] if params[:min_receptions]
		buyer.max_receptions = params[:max_receptions] if params[:max_receptions]
		buyer.mortgage_approval = params[:mortgage_approval] if params[:mortgage_approval]
		buyer.password = params[:password] if params[:password]
    if buyer.buying_status == PropertyBuyer::BUYING_STATUS_HASH['Looking to rent']
      rent_requirement = buyer.rent_requirement
      rent_requirement ||= RentRequirement.new 
      rent_requirement.buyer_id = buyer.id
      if rent_requirement_params
        rent_requirement.min_beds = rent_requirement_params[:min_beds] if rent_requirement_params[:min_beds]
        rent_requirement.max_beds = rent_requirement_params[:max_beds] if rent_requirement_params[:max_beds]
        rent_requirement.min_baths = rent_requirement_params[:min_baths] if rent_requirement_params[:min_baths]
        rent_requirement.max_baths = rent_requirement_params[:max_baths] if rent_requirement_params[:max_baths]
        rent_requirement.min_receptions = rent_requirement_params[:min_receptions] if rent_requirement_params[:min_receptions]
        rent_requirement.max_receptions = rent_requirement_params[:max_receptions] if rent_requirement_params[:max_receptions]
        rent_requirement.locations = rent_requirement_params[:locations] if rent_requirement_params[:locations]
        rent_requirement.save!
      end
    end
		buyer.save!
    details = buyer.as_json
    details['buying_status'] = PropertyBuyer::REVERSE_BUYING_STATUS_HASH[details['buying_status']]
    details['funding'] = PropertyBuyer::REVERSE_FUNDING_STATUS_HASH[details['funding']]
    details['status'] = PropertyBuyer::REVERSE_STATUS_HASH[details['status']]
		render json: { message: 'Saved buyer successfully', details: details }, status: 200
	end

  #### Serves predictions for the buyers
  #### curl -XGET  'http://localhost/buyers/predict?str=test10@pr'
  def predictions
    buyer_suggestions = PropertyBuyer.suggest_buyers(params[:str]).select([:id, :name, :image_url]).limit(20)
    render json: buyer_suggestions, status: 200
  end

  #### buyer tracking history
  #### curl -XGET -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo"  'http://localhost/buyers/tracking/history'
  def tracking_history
    buyer = user_valid_for_viewing?('Buyer')
    if !buyer.nil?
      events = Events::Track.where(buyer_id: buyer.id).order("created_at desc")
      results = events.map do |event|
        {
          udprn: event.udprn,
          hash_str: event.hash_str,
          type_of_tracking:  Events::Track::REVERSE_TRACKING_TYPE_MAP[event.type_of_tracking],
          created_at: event.created_at,
          tracking_id: event.id
        }
      end
      render json: results, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end


  ### Premium access for buyers for tracking localities, streets and property
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 
  ### -H "Content-Type: application/json"  "http://localhost/buyers/premium/access" -d  '{ "stripeEmail" : "abhiuec@gmail.com", "stripeToken":"tok_19WlE9AKL3KAwfPBkWwgTpqt", "buyer_id":211}'
  def process_premium_payment
    buyer = @current_user
    # Create the customer in Stripe
    customer = Stripe::Customer.create(
      email: params[:stripeEmail],
      card: params[:stripeToken]
    )
    chargeable_amount = (PropertyBuyer::PREMIUM_AMOUNT)*100.0
    begin
      charge = Stripe::Charge.create(
        customer: customer.id,
        amount: chargeable_amount,
        description: "Ads amount charged for premium access for buyer id, #{params[:buyer_id]} on #{Time.now.to_s}",
        currency: 'GBP'
      )

      ### Upgrade to premium
      PropertyBuyer.find(buyer.id).update_attributes(is_premium: true)

      ### Notify a vendor that a vendor has upgraded to premium
      VendorUpgradePremiumNotifyVendorWorker.perform_async(buyer.vendor_id)

      message = 'Premium access for trackings enabled'
    rescue Stripe::CardError => e
      Rails.logger.info("STRIPE_CARD_ERROR_#{buyer_id}: #{e.message}")
      message = "Stripe card error with message #{e.message}"
    ensure
      render json: { message: message, status: 200 }
    end
  end

  ### Get tracking stats for a buyer
  # curl -XGET  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c"   "http://localhost/buyers/tracking/stats"  
  def tracking_stats
    buyer = @current_user
    property_tracking_count = Events::Track.where(buyer_id: buyer.id).where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:property_tracking]).count
    street_tracking_count = Events::Track.where(buyer_id: buyer.id).where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:street_tracking]).count
    locality_tracking_count = Events::Track.where(buyer_id: buyer.id).where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:locality_tracking]).count
    stats = {
      type: (buyer.is_premium? ? 'Premium' : 'Standard'),
      locality_tracking_count_limit: Events::Track::BUYER_LOCALITY_PREMIUM_LIMIT[buyer.is_premium.to_s],
      street_tracking_count_limit: Events::Track::BUYER_STREET_PREMIUM_LIMIT[buyer.is_premium.to_s],
      property_tracking_count_limit: Events::Track::BUYER_PROPERTY_PREMIUM_LIMIT[buyer.is_premium.to_s],
      locality_tracking_count: locality_tracking_count,
      property_tracking_count: property_tracking_count,
      street_tracking_count: street_tracking_count
    }
    render json: stats, status: 200
  end

  ### Get tracking filters and find details of properties in type of tracking
  ### TODO: Net HTTP calls made with hardcoded hostnames to be removed
  ### TODO: tracking id should be returned or not?
  def tracking_details
    buyer = @current_user
    type_of_tracking = (params[:type_of_tracking] || "property_tracking").to_sym
    if type_of_tracking == :property_tracking
      udprns = Events::Track.where(buyer_id: buyer.id).where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[:property_tracking]).pluck(:udprn)
      api = PropertySearchApi.new(filtered_params: {})
      body = api.fetch_details_from_udprns(udprns)
      render json: {property_details: body}, status: 200
    else
      if params["hash_str"].present?
        body = Oj.load(Net::HTTP.get(URI.parse(URI.encode("http://52.66.124.42/api/v0/properties/search?hash_str=#{params['hash_str']}"))))
        render json: {property_details: body}, status: 200
      else
        body = []
        search_hashes = Events::Track.where(buyer_id: buyer.id).where(type_of_tracking: Events::Track::TRACKING_TYPE_MAP[type_of_tracking]).pluck(:hash_str).compact
        search_hashes.each do |search_hash|
          ### TODO: Fix this. Use internal methods rather than calling the api
          body = Oj.load(Net::HTTP.get(URI.parse(URI.encode("http://api.prophety.co.uk/api/v0/properties/search?hash_str=#{search_hash}")))) + body
        end
        render json: {search_hashes: search_hashes, property_details: body}
      end
    end
  end

  ### Edit tracking details
  # curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c"   "http://localhost/buyers/tracking/remove/:tracking_id"  
  def edit_tracking
    buyer = @current_user
    destroyed = Events::Track.where(id: params[:tracking_id].to_i).last.destroy
    render json: { message: 'Destroyed tracking request' }, status: 200
  end

  ### Vendors api for submitting user card info when subscribing to a premium service
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" -H "Content-Type: application/json" 'http://localhost/users/subscribe/premium/service' -d '{ "stripeEmail" : "email", "stripeToken" : "token" }'
  def subscribe_premium_service
    buyer = @current_user
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    payload = request.body.read
    begin
      # Create the customer in Stripe
      customer = Stripe::Customer.create(
        email: params[:stripeEmail],
        card: params[:stripeToken]
      )
      stripe_subscription = customer.subscriptions.create(:plan => 'user_premium-monthly')
      buyer.is_premium = true
      buyer.stripe_customer_id = customer.id
      buyer.premium_expires_at = 1.month.from_now.to_date
      buyer.save!

      ### Notify a vendor that a vendor has upgraded to premium
      VendorUpgradePremiumNotifyVendorWorker.perform_async(buyer.vendor_id)

      render json: { message: 'Created a monthly subscription for premium service' }, status: 200
    rescue JSON::ParserError => e
      # Invalid payload
      status 400
      render json: { message: 'JSON parser error' }, status: 400
    rescue Stripe::SignatureVerificationError => e
      # Invalid signature
      render json: { message: 'Invalid Signature' }, status: 400
    rescue Exception => e
      Rails.logger.info(e.message)
      render json: { message: 'Unable to create Stripe customer and charge. Please retry again' }, status: 400
    end
  end

  ### Stripe agents subscription recurring payment
  ### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo4OCwiZXhwIjoxNTAzNTEwNzUyfQ.7zo4a8g4MTSTURpU5kfzGbMLVyYN_9dDTKIBvKLSvPo" 'http://localhost/agents/premium/subscription/remove'
  def remove_subscription
    buyer = @current_user
    customer_id = buyer.stripe_customer_id
    customer = Stripe::Customer.retrieve(customer_id)
    subscription.delete
    render json: { message: 'Unsubscribed succesfully' }, status: 200
  end

  ### Info about the premium charges monthly
  ### curl -XGET 'http://localhost/agents/premium/cost'
  def info_premium
    render json: { value: (PropertyBuyer::PREMIUM_COST*100) }, status: 200
  end

  def test_view
    render "test_view"
  end

  private

  def user_valid_for_viewing?(klass)
    AuthorizeApiRequest.call(request.headers, klass).result
  end

  def authenticate_buyer
    @current_user = user_valid_for_viewing?('Buyer')
    if @current_user
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end
end

