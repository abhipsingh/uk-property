#### Emulation of a request for each action is given
class QuotesController < ApplicationController

  #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
  #### He/She submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
  #### He/She does it through this api. Examples are given below
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
  #### Another example.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
  def new_quote_for_property
    service = QuoteService.new(params[:udprn].to_i)
    response = service.new_quote_for_property(params[:services_required], params[:payment_terms],
                                              params[:quote_details], params[:assigned_agent])
    render json: response, status: 200
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
    service = QuoteService.new(params[:udprn].to_i)
    response = service.submit_price_for_quote(params[:agent_id].to_i, params[:payment_terms], 
                                              params[:quote_details], params[:services_required])
    render json: response, status: 200
  # rescue Exception => e
    # render json: { message: 'QuotesController#new error occurred' }, status: 200
  end

  ##### When submit quote button is clicked, the property data needs to be sent for the
  ##### form to be rendered.
  ##### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/quotes/submit/2'
  ##### curl -XPOST  -H "Content-Type: application/json" 'http://localhost/quotes/submit/:quote_id'
  def submit
    quote_id = params[:quote_id]
    property_id = params[:udprn].to_i
    #### When the quote is won
    service = QuoteService.new(params[:udprn].to_i)
    agent_id = Agents::Branches::AssignedAgents::Quote.find(quote_id).agent_id
    message = service.accept_quote_from_agent(agent_id)
    render json: message, status: 200
  end

  ##### Shows all the quotes that were submitted by the agents to the vendors
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/property/quotes/agents/10966139'
  def quotes_per_property
    property_id = params[:udprn].to_i
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    agents_for_quotes = Agents::Branches::AssignedAgents::Quote.where(status: status).where.not(agent_id: nil).where.not(agent_id: 1).where(property_id: property_id)
    final_result = []
    agents_for_quotes.each do |each_agent_id|
      quotes = AgentApi.new(property_id.to_i, each_agent_id.agent_id.to_i).calculate_quotes
      quotes[:quote_id] = each_agent_id.id
      final_result.push(quotes)
    end
    final_result = final_result.uniq{ |t| t[:id] }
    render json: final_result, status: 200
  end
  
  #### Shows all the properties available for quoting
end
