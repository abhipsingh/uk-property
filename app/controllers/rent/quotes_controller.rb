#### Emulation of a request for each action is given
module Rent
  class QuotesController < ApplicationController
    include CacheHelper
    around_action :authenticate_agent, only: [ :new, :edit_agent_quote ]
    around_action :authenticate_vendor, only: [ :submit, :quote_details, :historical_vendor_quotes ]
  
    #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
    #### He/She submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
    #### He/She does it through this api. Examples are given below
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
    #### Another example.
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
    def new_quote_for_property
      service = Rent::PropertyQuoteService.new(params[:udprn].to_i)
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      existing_agent_id = details[:agent_id]
      vendor_id = details[:vendor_id]
      buyer = PropertyBuyer.where(vendor_id: vendor_id).last
      yearly_quote_count = Rent::Quote.where(vendor_id: vendor_id).where("created_at > ?", 1.year.ago).count
      if yearly_quote_count <= Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s]
        response, status = service.new_quote_for_property(params[:payment_terms], params[:assigned_agent], existing_agent_id)
        render json: response, status: status
      else
        render json: { message: "Yearly quota limit for vendor has exceeded #{Rent::Quote::VENDOR_LIMIT}. You have claimed #{yearly_quote_count} quotes till now in this year ", quotes_count: yearly_quote_count, quote_limit: Rent::Quote::VENDOR_LIMIT }, status: 400
      end
    end
  
    #### When a new quote is entered by an agent
    #### Flow is submit a quote --> new quote
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":500, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": 200, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 200, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 1000, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}" }'
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : 4500 \} \]  \}, \"advertising\" : \{ \"price\": 0, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": 0, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 0, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 0, \"list_of_services\" : \[  \]  \}     \}" }'
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
    def new
      agent = @current_user
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      klass = Rent::Quote
      service = Rent::PropertyQuoteService.new(params[:udprn].to_i)
      response = service.submit_price_for_quote(params[:agent_id].to_i, params[:payment_terms], params[:quote_price].to_i, params[:terms_url])
      render json: response, status: 200
    end
  
    #### When a new quote is entered by an agent
    #### Flow is submit a quote --> new quote
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/edit/'  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" -d '{ "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
    def edit_agent_quote
      agent = @current_user
      service = Rent::PropertyQuoteService.new(params[:udprn].to_i)
      response = service.edit_quote_details(params[:agent_id].to_i, params[:payment_terms], params[:quote_price].to_i, params[:terms_url])
      render json: response, status: 200
    end
  
    ##### When submit quote button is clicked, the property data needs to be sent for the
    ##### form to be rendered.
    ##### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/quotes/submit/2'
    ##### curl -XPOST  -H "Authorization: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo0MywiZXhwIjoxNDg1NTMzMDQ5fQ.KPpngSimK5_EcdCeVj7rtIiMOtADL0o5NadFJi2Xs4c" 'http://localhost/quotes/submit/:quote_id'
    def submit
      agent = @current_user
      #if true
      quote_id = params[:quote_id]
      #### When the quote is won
      quote = Rent::Quote.find(quote_id)
      new_status = Rent::Quote::STATUS_HASH['New']
      if !quote.expired && quote.status == new_status && (Time.now > (quote.created_at + Rent::Quote::MAX_AGENT_QUOTE_WAIT_TIME)) && (Time.now < (quote.created_at + Rent::Quote::MAX_VENDOR_QUOTE_WAIT_TIME))
        service = Rent::PropertyQuoteService.new(quote.property_id)
        agent_id = quote.agent_id
        message = service.accept_quote_from_agent(agent_id)
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
        status = Rent::Quote::STATUS_HASH['New']
  
        final_result = []
        ### Last vendor quote submitted for this property
        vendor_quote = Rent::Quote.where(expired: false).where(agent_id: nil).where(property_id: property_id).where.not(vendor_id: nil).last
        if vendor_quote
          final_result = Rent::PropertyQuoteService.new(udprn: property_id).fetch_all_agent_quotes
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
      quote = Rent::Quote.where(id: params[:id].to_i, vendor_id: vendor.id).last
      render json: quote, status: 200
    end
    
    ### vendor Quote details api
    ### curl -XGET 'http://localhost/property/quotes/property/:udprn'
    def property_quote
      quote = Rent::Quote.where(property_id: params[:udprn].to_i, agent_id: nil).last
      render json: quote, status: 200
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
          agent = Agents::Branches::AssignedAgent.find(params[:agent_id].to_i)
          agent_quote_service = Rent::AgentQuoteService.new(agent_id: agent_id)
          results = agent_quote_service.recent_properties_for_quotes(params[:payment_terms], params[:quote_status], agent.is_premium,
                                                                     params[:page], count, params[:latest_time])
          response = (!results.is_a?(Fixnum) && results.empty?) ? {"quotes" => results, "message" => "No claims to show"} : {"quotes" => results}
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
end
