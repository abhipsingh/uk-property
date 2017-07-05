class QuoteService

  attr_accessor :udprn

  def initialize(udprn)
    @udprn = udprn
  end

  def submit_price_for_quote(agent_id, payment_terms, quote_details, services_required)
    deadline = 24.hours.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[services_required]
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    details = PropertyDetails.details(@udprn)['_source']
    district = details['district']
    property_status_type = Trackers::Buyers::PROPERTY_STATUS_TYPES[details['_source']['property_status_type']]
    quote = Agents::Branches::AssignedAgents::Quote.create!(
      deadline: deadline,
      agent_id: agent_id,
      property_id: @udprn,
      property_status_type: property_status_type,
      status: status,
      payment_terms: payment_terms,
      quote_details: quote_details,
      service_required: services_required,
      district: district
    )
  end

  def new_quote_for_property(services_required, payment_terms, quote_details, assigned_agent)
    client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
    doc = {
      services_required: services_required,
      payment_terms: payment_terms,
      quotes: quote_details,
      assigned_agent_quote: assigned_agent,
      accepting_quotes: true
    }
    response, status = PropertyDetails.update_details(client, @udprn, doc)
    return response, status
  end

  def accept_quote_from_agent(agent_id)
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
    quote = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn.to_i, 
                                                          agent_id: agent_id, 
                                                          status: status).last
    quote_id = quote.id
    cond = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn.to_i,
                                                         status: won_status)
                                                  .count
    response = nil
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
      PropertyDetails.update_details(client, @udprn.to_i, doc)
      details = PropertyDetails.details(@udprn.to_i)
      response = { details: details, message: 'The quote is accepted' }
    else
      response = { message: 'Another quote for this property has already been accepted' }
    end
    response
  end

end
