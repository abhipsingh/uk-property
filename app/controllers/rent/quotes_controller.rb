#### Emulation of a request for each action is given
module Rent
  class QuotesController < ApplicationController
    include CacheHelper
    around_action :authenticate_agent, only: [ :new, :edit_agent_quote,  ]
    around_action :authenticate_vendor, only: [ :submit, :quote_details, :new_quote_for_property, :quotes_per_property ]
  
    #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
    #### He/She submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
    #### He/She does it through this api. Examples are given below
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
    #### Another example.
    #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
    def new_quote_for_property
      service = Rent::PropertyQuoteService.new(udprn: params[:udprn].to_i)
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      assigned_agent = (params[:assigned_agent].to_s == 'true')
      vendor_id = details[:vendor_id]
      buyer = PropertyBuyer.where(vendor_id: vendor_id).last
      yearly_quote_count = Rent::Quote.where(vendor_id: vendor_id).where("created_at > ?", 1.year.ago).count
      if yearly_quote_count <= Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s]
        existing_agent_id = details[:agent_id].to_i
        vendor_id = details[:vendor_id].to_i
        district = details[:district].to_s
        response, status = service.new_quote_for_property(assigned_agent, existing_agent_id, district, vendor_id)
        render json: response, status: status
      else
        render json: { message: "yearly quota limit for vendor has exceeded #{Rent::QUOTE_LIMIT_MAP[buyer.is_premium.to_s]}. you have claimed #{yearly_quote_count} quotes till now in this year ", quotes_count: yearly_quote_count, quote_limit: Vendor::QUOTE_LIMIT_MAP[buyer.is_premium.to_s] }, status: 400
      end
    end
  
    #### when a new quote is entered by an agent
    #### flow is submit a quote --> new quote
    #### curl -xpost -h "content-type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "fixed price", "payment_terms" : "pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"full\"\]  \}  \}" }'
    #### curl -xpost -h "content-type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "ala carte", "payment_terms" : "pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"photographs\"\]  \}, \"advertising\" : \{ \"price\":500, \"list_of_services\" : \[ \"for sale board\", \"featured property listing on our site for search terms(30 days)\", \"premium property listing on our site for search terms(30 days)\", \"zoopla listing\", \"primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": 200, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 200, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 1000, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}" }'
    #### curl -xpost -h "content-type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "ala carte", "payment_terms" : "pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[ \{ \"type\" : \"photographs\", \"price\" : 4500 \} \]  \}, \"advertising\" : \{ \"price\": 0, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": 0, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 0, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 0, \"list_of_services\" : \[  \]  \}     \}" }'
    #### curl -xpost -h "content-type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "fixed price", "payment_terms" : "pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"full\"\]  \}  \}" }'
    def new
      agent = @current_user
      details = PropertyDetails.details(params[:udprn].to_i)[:_source]
      klass = Rent::Quote
      service = Rent::PropertyQuoteService.new(udprn: params[:udprn].to_i)
      response = service.submit_price_for_quote(params[:agent_id].to_i, params[:payment_terms], params[:quote_price].to_i, params[:terms_url])
      render json: response, status: 200
    end
  
    #### when a new quote is entered by an agent
    #### flow is submit a quote --> new quote
    #### curl -xpost -h "content-type: application/json" 'http://localhost/quotes/edit/'  -h "authorization: eyj0exaioijkv1qilcjhbgcioijiuzi1nij9.eyj1c2vyx2lkijo0mywizxhwijoxndg1ntmzmdq5fq.kppngsimk5_ecdcevj7rtiimotadl0o5nadfji2xs4c" -d '{ "udprn" : "10966139",  "services_required" : "fixed price", "payment_terms" : "pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"full\"\]  \}  \}" }'
    def edit_agent_quote
      agent = @current_user
      service = Rent::PropertyQuoteService.new(udprn: params[:udprn].to_i)
      response = service.edit_quote_details(params[:agent_id].to_i, params[:payment_terms], params[:quote_price].to_i, params[:terms_url])
      render json: response, status: 200
    end
  
    ##### when submit quote button is clicked, the property data needs to be sent for the
    ##### form to be rendered.
    ##### curl -xpost  -h "content-type: application/json" 'http://localhost/quotes/submit/2'
    ##### curl -xpost  -h "authorization: eyj0exaioijkv1qilcjhbgcioijiuzi1nij9.eyj1c2vyx2lkijo0mywizxhwijoxndg1ntmzmdq5fq.kppngsimk5_ecdcevj7rtiimotadl0o5nadfji2xs4c" 'http://localhost/quotes/submit/:quote_id'
    def submit
      agent = @current_user
      #if true
      quote_id = params[:quote_id]
      #### when the quote is won
      quote = Rent::Quote.find(quote_id)
      new_status = Rent::Quote::STATUS_HASH['New']
      if !quote.expired && quote.status == new_status && (Time.now > (quote.created_at + Rent::Quote::MAX_AGENT_QUOTE_WAIT_TIME)) && (Time.now < (quote.created_at + Rent::Quote::MAX_VENDOR_QUOTE_WAIT_TIME))
        service = Rent::PropertyQuoteService.new(udprn: quote.property_id)
        agent_id = quote.agent_id
        message = service.accept_quote_from_agent(agent_id)
        render json: message, status: 200
      else
        message = 'current time is not within the time bounds'
        render  json: message, status: 400
      end
    end
  
    ##### shows all the quotes that were submitted by the agents to the vendors
    ##### curl -xget  -h "content-type: application/json" 'http://localhost/property/quotes/agents/10966139'
    def quotes_per_property
      cache_response(params[:udprn].to_i, []) do
        property_id = params[:udprn].to_i
        status = Rent::Quote::STATUS_HASH['New']
  
        final_result = []
        ### last vendor quote submitted for this property
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
  
    ### quote details api
    ### curl -xget 'http://localhost/property/quotes/details/:id'
    def quote_details
      vendor = @current_user
      quote = Rent::Quote.where(id: params[:id].to_i, vendor_id: vendor.id).last
      render json: quote, status: 200
    end
    
    ### vendor quote details api
    ### curl -xget 'http://localhost/property/quotes/property/:udprn'
    def property_quote
      quote = Rent::Quote.where(udprn: params[:udprn].to_i, agent_id: nil).last
      render json: quote, status: 200
    end
  
    #### for agents the quotes page has to be shown in which all his recent or the new properties in the area
    #### will be published
    #### curl -xget -h "content-type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234'
    #### for applying filters i) payment_terms
    #### curl -xget -h "content-type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&payment_terms=pay%20upfront'
    #### ii) services_required
    #### curl -xget -h "content-type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&services_required=ala%20carte'
    #### ii) quote_status
    #### curl -xget -h "content-type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&quote_status=won'
    #### ii) rent or sale
    #### curl -xget -h "content-type: application/json" 'http://localhost/agents/properties/recent/quotes?agent_id=1234&property_for=rent'
    def agents_recent_properties_for_quotes
      cache_parameters = [ :agent_id, :payment_terms, :services_required, :quote_status, :hash_str, :property_for ]
      results = []
      response = {}
      status = 200
      count = params[:count].to_s == 'true'
      agent = @current_user
      agent_quote_service = Rent::AgentQuoteService.new(agent_id: agent.id)
      results = agent_quote_service.recent_properties_for_quotes(params[:payment_terms], params[:quote_status], agent.is_premium,
                                                                 params[:page], count, params[:latest_time])
      response = (!results.is_a?(fixnum) && results.empty?) ? {"quotes" => results, "message" => "no claims to show"} : {"quotes" => results}
      render json: response, status: status
    end
  
    #### shows all the properties available for quoting
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
