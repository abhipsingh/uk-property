#### Emulation of a request for each action is given
class QuotesController < ApplicationController

  #### When a vendor changes the status to Green or when a vendor selects a Fixed or Ala Carte option,
  #### He submits his preferences about the type of quotes he would want to receieve, Fixed or Ala carte
  #### He does it through this api. Examples are given below
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[ \{ \"type\" : \"Photographs\", \"price\" : null \} \]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[  \]  \}     \}", "assigned_agent": true }'
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Ala Carte", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"setup\" : \{ \"price\" : null, \"list_of_services\" : \[\"Photographs\"\]  \}, \"advertising\" : \{ \"price\":null, \"list_of_services\" : \[ \"For sale board\", \"Featured property listing on our site for search terms(30 days)\", \"Premium property listing on our site for search terms(30 days)\", \"Zoopla listing\", \"Primelocation listing\"  \]\}, \"buyer_qualification\" :  \{ \"price\": null, \"list_of_services\" : \[ \]  \},  \"schedule_viewings\" : \{ \"price\" : null, \"list_of_services\" : \[\]  \},  \"sales_progression\" : \{ \"price\" : null, \"list_of_services\" : \[ \"under_offer\", \"memorandum_of_sale\", \"mortgage_valuation\", \"conveyancing\", \"exchange\", \"complete\" \]  \}     \}", "assigned_agent": true }'
  #### Another example.
  #### curl -XPOST -H "Content-Type: application/json" 'http://localhost/quotes/property/10966139' -d '{ "services_required" : "Fixed Price", "payment_terms" : "Pay upfront", "quote_details" : "\{ \"fixed_price_services_requested\" : \{ \"price\" : null, \"list_of_services\" : \[\"Full\"\]  \}  \}", "assigned_agent": true }'
  def new_quote_for_property
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    current_time = Time.now.to_s
    current_time = current_time[0..current_time.rindex(" ")-1]
    doc = {
      services_required: params[:services_required],
      payment_terms: params[:payment_terms],
      quotes: params[:quote_details],
      assigned_agent_quote: params[:assigned_agent],
      status_last_updated: current_time,
      accepting_quotes: true
    }

    response = client.update index: 'addresses', type: 'address', id: params[:udprn].to_i, body: { doc: doc }
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
    property_id = params[:udprn].to_i
    deadline = 24.hours.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[params[:services_required]]
    payment_terms = params[:payment_terms]
    status = Agents::Branches::AssignedAgents::Quote::REVERSE_STATUS_HASH['New']
    agent_id = params[:agent_id].to_i
    quote_details = params[:quote_details]
    Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    details = PropertyDetails.details(property_id)['_source']
    district = details['district']
    quote = Agents::Branches::AssignedAgents::Quote.create!(
      deadline: deadline,
      agent_id: agent_id,
      property_id: property_id,
      status: status,
      payment_terms: payment_terms,
      quote_details: quote_details,
      service_required: services_required,
      district: district
    )

    render json: quote, status: 200
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
    cond = Agents::Branches::AssignedAgents::Quote.where(property_id: property_id).where(status: 3).count
    if cond == 0
      quote = Agents::Branches::AssignedAgents::Quote.where(id: quote_id.to_i).last
      quote.status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
      quote.save!
      client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
      current_time = Time.now.to_s
      current_time = current_time[0..current_time.rindex(" ")-1]
      doc = {
        services_required: quote.service_required,
        payment_terms: quote.payment_terms,
        quotes: quote.quote_details.to_json,
        status_last_updated: current_time,
        agent_id: quote.agent_id,
        accepting_quotes: false
      }

      client.update index: 'addresses', type: 'address', id: property_id.to_i, body: { doc: doc }
      details = PropertyDetails.details(property_id)
      render json: { details: details, message: 'The quote is accepted' }, status: 200
    else
      render json: {message: 'Another quote for this property has already been accepted'}, status: 200
    end
  end

  ##### Shows all the quotes that were submitted by the agents to the vendors
  ##### curl -XGET  -H "Content-Type: application/json" 'http://localhost/property/quotes/agents/10966139'
  def quotes_per_property
    property_id = params[:udprn].to_i
    agents_for_quotes = Agents::Branches::AssignedAgents::Quote.where(status: nil).where.not(agent_id: nil).where.not(agent_id: 1).where(property_id: property_id)
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
