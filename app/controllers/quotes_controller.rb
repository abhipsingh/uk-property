#### Emulation of a request for each action is given
class QuotesController < ApplicationController
  include CacheHelper

  #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
  #### He/She submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
  #### He/She does it through this api. Examples are given below
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
  #### Another example.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
  def new_quote_for_property
    service = QuoteService.new(params[:udprn].to_i)
    vendor_id = PropertyDetails.details(params[:udprn].to_i)[:_source][:vendor_id]
    yearly_quote_count = Agents::Branches::AssignedAgents::Quote.where(vendor_id: vendor_id).where("created_at > ?", 1.year.ago).group(:property_id).select("count(id)").to_a.count
    if yearly_quote_count <= Agents::Branches::AssignedAgents::Quote::VENDOR_LIMIT
      response, status = service.new_quote_for_property(params[:services_required], params[:payment_terms],
                                              params[:quote_details], params[:assigned_agent])
      render json: response, status: status
    else
      render json: { message: "Yearly quota limit for vendor has exceeded #{Agents::Branches::AssignedAgents::Quote::VENDOR_LIMIT}. You have claimed #{yearly_quote_count} quotes till now in this year ", quotes_count: yearly_quote_count, quote_limit: Agents::Branches::AssignedAgents::Quote::VENDOR_LIMIT }, status: 400
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
    agent = user_valid_for_viewing?('Agent')
    if agent
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      current_valuation = details[:current_valuation].to_i
      if current_valuation > 0
        if agent.credit > Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_f)
          service = QuoteService.new(params[:udprn].to_i)
          response = service.submit_price_for_quote(params[:agent_id].to_i, params[:payment_terms], 
                                                    params[:quote_details], params[:services_required], params[:terms_url])
          render json: response, status: 200
        else
          render json: { message: "Credits possessed for quotes #{agent.credit}, not more than #{Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01} ", current_valuation: current_valuation, cost_of_quote: (Agents::Branches::AssignedAgent::CURRENT_VALUATION_PERCENT*0.01*(current_valuation.to_i.to_f)), beds: details[:beds], baths: details[:baths], receptions: details[:receptions], street_view_image_url: details[:street_view_image_url], pictures: details[:pictures] }, status: 400
        end
      else
        render json: { message: 'Current valuation of the property, does not exist' }, status: 400
      end
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  # rescue Exception => e
    # render json: { message: 'QuotesController#new error occurred' }, status: 200
  end



  #### When a new quote is entered by an agent
  #### Flow is submit a quote --> new quote
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/edit/'  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -d '{ "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  def edit_agent_quote
    agent = user_valid_for_viewing?('Agent')
    if agent
      service = QuoteService.new(params[:udprn].to_i)
      response = service.edit_quote_details(params[:agent_id].to_i, params[:payment_terms], 
                                                  params[:quote_details], params[:services_required], params[:terms_url])
      render json: response, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ##### When submit quote button is clicked, the property data needs to be sent for the
  ##### form to be rendered.
  ##### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/quotes/submit/2'
  ##### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/submit/:quote_id'
  def submit
    agent = user_valid_for_viewing?('Vendor')
    if agent
    #if true
      quote_id = params[:quote_id]
      #### When the quote is won
      quote = Agents::Branches::AssignedAgents::Quote.find(quote_id)
      service = QuoteService.new(quote.property_id)
      agent_id = quote.agent_id
      message = service.accept_quote_from_agent(agent_id)
      render json: message, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ##### Shows all the quotes that were submitted by the agents to the vendors
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/property/quotes/agents/10966139'
  def quotes_per_property
    cache_response(params[:udprn].to_i, []) do
      property_id = params[:udprn].to_i
      status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']

      ### 24 hour expiry deadline for vendors
      agents_for_quotes = Agents::Branches::AssignedAgents::Quote.where(status: status).where.not(agent_id: nil).where.not(agent_id: 0).where.not(agent_id: 1).where(property_id: property_id).where('created_at > ?', Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME.ago)
      final_result = []
      agents_for_quotes.each do |each_agent_id|
        quotes = AgentApi.new(property_id.to_i, each_agent_id.agent_id.to_i).calculate_quotes
        quotes[:quote_id] = each_agent_id.id
        final_result.push(quotes)
      end
      final_result = final_result.uniq{ |t| t[:id] }
      render json: final_result, status: 200
    end
  end

  ### Quote details api
  ### curl -XGET 'http://localhost/property/quotes/details/:id'
  def quote_details
    vendor = user_valid_for_viewing?('Vendor')
    if vendor
      quote = Agents::Branches::AssignedAgents::Quote.where(id: params[:id].to_i, vendor_id: vendor.id).last
      render json: quote, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end
  
  ### vendor Quote details api
  ### curl -XGET 'http://localhost/property/quotes/property/:udprn'
  def property_quote
    quote = Agents::Branches::AssignedAgents::Quote.where(property_id: params[:udprn].to_i,agent_id: nil).last
    render json: quote, status: 200
  end

  ### Get all quotes for an agent
  ### curl -XGET   -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/agents/history' 
  def historical_agent_quotes
    agent = user_valid_for_viewing?('Agent')
    if agent
      results = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent.id).order('created_at DESC').map do |quote|
        hash = {
          created_at: quote.created_at,
          payment_terms: quote.payment_terms,
          quote_details: quote.quote_details,
          udprn: quote.property_id,
          expired: quote.expired,
          refund_status: quote.refund_status,
          service_required: Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[quote.service_required.to_s.to_sym],
          status: Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quote.status]
        }
        hash[:status] = 'Pending' if (hash[:status] == 'New' && !hash[:expired])
        hash 
      end
      render json: results, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  ### Get all quotes for a property(historically)
  ### curl -XGET   -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/vendors/history/:udprn' 
  def historical_vendor_quotes
    vendor = user_valid_for_viewing?('Vendor')
    if vendor
      udprn = params[:udprn].to_i
      results = Agents::Branches::AssignedAgents::Quote.where(property_id: udprn).order('created_at DESC').map do |quote|
        hash = {
          created_at: quote.created_at,
          agent_id: quote.agent_id,
          payment_terms: quote.payment_terms,
          quote_details: quote.quote_details,
          expired: quote.expired,
          refund_status: quote.refund_status,
          service_required: Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[quote.service_required.to_s.to_sym],
          status: Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH[quote.status]
        }
        hash[:status] = 'Pending' if (hash[:status] == 'New' && !hash[:expired])
        hash
      end
      render json: results, status: 200
    else
      render json: { message: 'Authorization failed' }, status: 401
    end
  end

  #### Shows all the properties available for quoting
  private
  def user_valid_for_viewing?(klass)
    AuthorizeApiRequest.call(request.headers, klass).result
  end
end
