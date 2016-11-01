#### Emulation of a request for each action is given
class QuotesController < ApplicationController

  #### When a new quote is entered by an agent
  #### Flow is submit a quote --> new quote
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":500, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": 200, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : 200, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : 1000, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}" }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/new' -d '{"agent_id" : 1234, "udprn" : "10966139",  "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : 4500, \"list_of_services\" : \[\"Full\"\]  \}  \}" }'
  def new
    property_id = params[:udprn].to_i
    deadline = 24.hours.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[params[:services_required]]
    payment_terms = params[:payment_terms]
    status = Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH['New']
    agent_id = params[:agent_id].to_i
    quote_details = params[:quote_details]
    Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    quote = Agents::Branches::AssignedAgents::Quote.create!(
      deadline: deadline,
      agent_id: agent_id,
      property_id: property_id,
      status: status,
      payment_terms: payment_terms,
      quote_details: quote_details,
      service_required: services_required
    )
    render json: quote, status: 200
  # rescue Exception => e
    # render json: { message: 'QuotesController#new error occurred' }, status: 200
  end

  ##### When submit quote button is clicked, the property data needs to be sent for the
  ##### form to be rendered.
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/quotes/submit?udprn=10966139'
  def submit
    property_id = params[:udprn].to_i
    details = PropertyDetails.details(property_id)
    render json: details, status: 200
  end

  ##### When submit quote button is clicked, the property data needs to be sent for the
  ##### form to be rendered.
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/property/quotes/agents/10966139'
  def quotes_per_property
    property_id = params[:udprn].to_i
    agents_for_quotes = Agents::Branches::AssignedAgents::Quote.where(status: nil).where(property_id: property_id).pluck(:agent_id).uniq
    final_result = []
    agents_for_quotes.each do |each_agent_id|
      quotes = AgentApi.new(property_id.to_i, each_agent_id.to_i).calculate_quotes
      final_result.push(quotes)
    end
    render json: final_result, status: 200
  end
end
