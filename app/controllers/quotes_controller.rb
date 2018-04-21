#### Emulation of a request for each action is given
class QuotesController < ApplicationController
  include CacheHelper
  around_action :authenticate_agent, only: [ :new, :edit_agent_quote, :agents_recent_properties_for_quotes ]
  around_action :authenticate_vendor, only: [ :submit, :quote_details, :new_quote_for_property, :quotes_per_property ]

  #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
  #### He/She submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
  #### He/She does it through this api. Examples are given below
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
  #### Another example.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
  def new_quote_for_property
    service = QuoteService.new(params[:udprn].to_i)
    details = PropertyDetails.details(params[:udprn].to_i)[:_source]
    existing_agent_id = details[:agent_id]
    vendor_id = details[:vendor_id]
    buyer = PropertyBuyer.where(vendor_id: vendor_id).last
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
    yearly_quote_count = Agents::Branches::AssignedAgents::Quote.where(vendor_id: vendor_id).where("created_at > ?", 1.year.ago).where("(status = ? AND expired='t' ) OR status = ?", new_status, won_status).count
    Rails.logger.info("VENDOR_NEW_QUOTE_#{vendor_id}_#{params[:udprn].to_i}_#{yearly_quote_count}_#{buyer.is_premium}")
    if yearly_quote_count < Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s]
      response, status = service.new_quote_for_property(params[:services_required], params[:payment_terms],
                                              params[:quote_details], params[:assigned_agent], existing_agent_id)
      render json: response, status: status
    else
      render json: { message: "Yearly quota limit for vendor has exceeded #{Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s]}. You have claimed #{yearly_quote_count} quotes till now in this year ", quotes_count: yearly_quote_count, quote_limit: Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s] }, status: 400
    end
  #rescue Exception => e
  #  render json: e, status: 400
  end

  #### When a new quote is entered by an agent
  #### Flow is submit a quote --> new quote
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":500, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": 200, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 200, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 1000, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}" }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : 4500 \} \]  \}, \"advertising\" : \{ \"price\": 0, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": 0, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 0, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 0, \"list_of_services\" : \[  \]  \}     \}" }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  def new
    agent = @current_user
    invited_vendor_emails = InvitedVendor.where(agent_id: agent.id).where(source: Vendor::INVITED_FROM_CONST[:family]).pluck(:email).uniq
    registered_vendor_count = Vendor.where(email: invited_vendor_emails).count
    Rails.logger.info("AGENT_NEW_QUOTE_#{agent.id}_#{params[:udprn].to_i}_#{registered_vendor_count}_#{invited_vendor_emails.count}")
    if registered_vendor_count >= Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      current_valuation = details[:current_valuation].to_i
      if current_valuation > 0

        klass = Agents::Branches::AssignedAgents::Quote
        entity_class = AgentCreditVerifier::KLASSES.index(klass.to_s)

        if agent.credit > ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_f)).round/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
          service = QuoteService.new(params[:udprn].to_i)
          response = service.submit_price_for_quote(params[:agent_id].to_i, params[:payment_terms], 
                                                    params[:quote_details], params[:services_required], params[:terms_url])

          ### Create a agent credit verifier to prevent duplicate entries
          AgentCreditVerifier.create!(entity_id: service.quote.id, entity_class: entity_class, agent_id: agent.id, udprn: params[:udprn].to_i, vendor_id: details[:vendor_id].to_i, amount: current_valuation.to_i)

          agent.credit -= ((Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_f)).round/Agents::Branches::AssignedAgent::PER_CREDIT_COST)
          agent.save!
          render json: response, status: 200
        else
          render json: { message: "Credits possessed for quotes #{agent.credit}, not more than #{Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01} ", current_valuation: current_valuation, cost_of_quote: (Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_i.to_f)), beds: details[:beds], baths: details[:baths], receptions: details[:receptions], street_view_image_url: details[:street_view_image_url], pictures: details[:pictures] }, status: 400
        end
      else
        render json: { message: 'Current valuation of the property, does not exist' }, status: 400
      end
    else
      render json: { message: "Invited friends family below the minimum value #{Agents::Branches::AssignedAgent::MIN_INVITED_FRIENDS_FAMILY_VALUE}" }, status: 400
    end
  end

  #### When a new quote is entered by an agent
  #### Flow is submit a quote --> new quote
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/edit/'  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -d '{ "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  def edit_agent_quote
    agent = @current_user
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']
    quote = klass.where(agent_id: agent.id, property_id: params[:udprn].to_i, expired: false, status: new_status).order('created_at DESC').first

    ### Only available for assigned agent
    details = PropertyDetails.details(params[:udprn].to_i)[:_source]

    if quote && details[:agent_id].to_i == agent.id
      service = QuoteService.new(params[:udprn].to_i)
      response = service.edit_quote_details(quote, params[:agent_id].to_i, params[:payment_terms], params[:quote_details],
                                            params[:services_required], params[:terms_url])
      render json: response, status: 200
    else
      render json: { message: 'Unable to edit quote' }, status: 400
    end
  end

  #### When a new quote is entered by  vendor
  #### Flow is submit a quote --> new quote
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/vendor/edit/'  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -d '{ "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  def edit_vendor_quote
    user = @current_user
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']
    quote = klass.where(parent_quote_id: nil, property_id: params[:udprn].to_i, expired: false, status: new_status).order('created_at DESC').first
    if quote
      service = QuoteService.new(params[:udprn].to_i)
      response = service.edit_vendor_quote_details(quote, user.id, params[:payment_terms], params[:quote_details],
                                            params[:services_required], params[:terms_url])
      render json: response, status: 200
    else
      render json: { message: 'Unable to edit quote' }, status: 400
    end
  end

  ##### When submit quote button is clicked, the property data needs to be sent for the
  ##### form to be rendered.
  ##### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/quotes/submit/2'
  ##### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/submit/:quote_id'
  def submit
    vendor = @current_user
    #if true
    quote_id = params[:quote_id]
    #### When the quote is won
    quote = Agents::Branches::AssignedAgents::Quote.find(quote_id)
    parent_quote = Agents::Branches::AssignedAgents::Quote.find(quote.parent_quote_id)
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    Rails.logger.info("QUOTE_SUBMIT_#{quote.id}_#{parent_quote.id}  #{(parent_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME)} #{(parent_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME)}  #{Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME} Status: #{quote.status}  Expired: #{quote.expired} ")
    if quote.expired
      message = 'This quote has already expired'
      render  json: message, status: 400
    elsif quote.status != new_status
      message = "The quote has already been #{Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quote.status].downcase}"
      render  json: message, status: 400
    elsif (Time.now > (parent_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME)) && (Time.now < (parent_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME))
      service = QuoteService.new(quote.property_id)
      agent_id = quote.agent_id
      property_id = quote.property_id
      message = service.accept_quote_from_agent(agent_id, quote)

      ### Send email to the agent who has won and who has lost the quote
      VendorAcceptQuoteNotifyAgentWorker.perform_async(property_id, agent_id)

      render json: message, status: 200
    else
      message = 'Current time is not within the time bounds'
      render  json: message, status: 400
    end
  end

  ##### Shows all the quotes that were submitted by the agents to the vendors
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/property/quotes/agents/10966139'
  def quotes_per_property
    cache_response(params[:udprn].to_i, []) do
      property_id = params[:udprn].to_i
      new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']

      final_result = []
      ### Last vendor quote submitted for this property
      vendor_quote = Agents::Branches::AssignedAgents::Quote.where(expired: false, parent_quote_id: nil, property_id: property_id).where.not(vendor_id: nil).order('created_at DESC').first
      if vendor_quote
        agents_for_quotes = Agents::Branches::AssignedAgents::Quote.where(status: new_status).where(expired: false).where(parent_quote_id: vendor_quote.id)
        agents_for_quotes.each do |each_agent_id|
          each_agent_quote = each_agent_id
          quotes = AgentApi.new(property_id.to_i, each_agent_id.agent_id.to_i).calculate_quotes(vendor_quote, each_agent_quote)
          quotes[:quote_id] = each_agent_id.id
          final_result.push(quotes)
        end
      else
        final_result = []
      end
      final_result = final_result.uniq{ |t| t[:id] }
      render json: final_result, status: 200
    end
  end

  ### Quote details api
  ### curl -XGET 'http://localhost/property/quotes/details/:id'
  def quote_details
    vendor = @current_user
    quote = Agents::Branches::AssignedAgents::Quote.where(id: params[:id].to_i, vendor_id: vendor.id).last
    render json: quote, status: 200
  end
  
  ### vendor Quote details api
  ### curl -XGET 'http://localhost/property/quotes/property/:udprn'
  def property_quote
    quote = Agents::Branches::AssignedAgents::Quote.where(property_id: params[:udprn].to_i,agent_id: nil).last
    render json: quote, status: 200
  end

  ### Get all quotes for a property(historically)
  ### curl -XGET   -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/vendors/history/:udprn' 
  def historical_vendor_quotes
    vendor = @current_user
    udprn = params[:udprn].to_i
    klass = Agents::Branches::AssignedAgents::Quote
    
    results = klass.where("expired = 't' OR status = ? OR status = ?", klass::STATUS_HASH['Won'], klass::STATUS_HASH['Lost']).where.not(agent_id: nil).where(property_id: udprn).order('created_at desc').map do |quote|
      agent = Agents::Branches::AssignedAgent.where(id: quote.agent_id).select([:first_name, :last_name, :email, :mobile, :title, :branch_id]).last
      branch = Agents::Branch.where(id: agent.branch_id).select([:phone_number]).last
      hash = {
        id: quote.id,
        created_at: quote.created_at,
        agent_id: quote.agent_id,
        agent_name: agent.first_name + ' ' + agent.last_name,
        agent_email: agent.email,
        agent_mobile: agent.mobile,
        agent_title: agent.title,
        payment_terms: quote.payment_terms,
        quote_details: quote.quote_details,
        expired: quote.expired,
        terms_url: quote.terms_url,
        refund_status: quote.refund_status,
        quote_price: quote.compute_price,
        branch_phone_number: agent.office_phone_number,
        services_required: Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[quote.service_required.to_s.to_sym],
        status: Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quote.status],
        parent_quote_id: quote.parent_quote_id
      }
      
      ### Merge aggregate stats
      agent_api = AgentApi.new(nil, quote.agent_id)
      agent_stats = {}
      agent_api.populate_aggregate_stats(agent_stats)
      agent_stats
      hash.merge!(agent_stats)

      agent = Agents::Branches::AssignedAgent.where(id: quote.agent_id).select([:first_name, :last_name, :image_url, :branch_id]).last
      hash[:agent_first_name] = agent.first_name
      hash[:agent_last_name] = agent.last_name
      hash[:agent_name] = agent.first_name + ' ' + agent.last_name
      hash[:agent_image_url] = agent.image_url
      hash[:assigned_agent_branch_logo] = agent.branch.image_url
      hash[:branch_id] = agent.branch_id
      hash[:status] = 'Pending' if (hash[:status] == 'New' && !hash[:expired])
      hash
    end
    render json: results, status: 200
  end

  #### For agents the quotes page has to be shown in which all his recent or the new properties in the area
  #### Will be published
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234'
  #### For applying filters i) payment_terms
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&payment_terms=Pay%20upfront'
  #### ii) services_required
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&services_required=Ala%20Carte'
  #### ii) quote_status
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&quote_status=Won'
  #### ii) Rent or Sale
  #### curl -XGET -H "Content-Type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&property_for=Rent'
  def agents_recent_properties_for_quotes
    cache_parameters = [ :agent_id, :payment_terms, :services_required, :quote_status, :hash_str, :property_for ]
    #cache_response(params[:agent_id].to_i, cache_parameters) do
      results = []
      response = {}
      status = 200
      count = params[:count].to_s == 'true'
      #begin
        agent = Agents::Branches::AssignedAgent.find(params[:agent_id])
        if !agent.locked
          results, count = agent.recent_properties_for_quotes(params[:payment_terms], params[:services_required], params[:quote_status], params[:hash_str], 'Sale', params[:buyer_id], agent.is_premium, params[:page], count, params[:latest_time])
          response = (!results.is_a?(Fixnum) && results.empty?) ? { quotes: results, message: 'No claims to show', count: count } : { quotes: results, count: count }
        else
          lead = Agents::Branches::AssignedAgents::Lead.where(agent_id: agent.id)
                                                       .where(expired: true)
                                                       .order('updated_at DESC')
                                                       .last
          address = PropertyDetails.details(lead.property_id)[:_source][:address]
          deadline = lead.created_at + Agents::Branches::AssignedAgents::Lead::VERIFICATION_DAY_LIMIT
          response = { quotes: [], address: address, locked: true }
          status = 400
        end
      #rescue => e
      #  Rails.logger.error "Error with agent quotes => #{e}"
      #  response = { quotes: results, message: 'Error in showing quotes', details: e.message}
      #  status = 500
      #end
      
      render json: response, status: status
    #end
  end

  #### Shows all the properties available for quoting
  private
  def user_valid_for_viewing?(klass)
    @current_user = AuthorizeApiRequest.call(request.headers, klass).result
  end

  def authenticate_agent
    if user_valid_for_viewing?('Agent')
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  def authenticate_vendor
    if user_valid_for_viewing?('Vendor')
      yield
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end
end

