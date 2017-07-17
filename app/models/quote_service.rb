class QuoteService

  attr_accessor :udprn

  def initialize(udprn)
    @udprn = udprn
  end

  def submit_price_for_quote(agent_id, payment_terms, quote_details, services_required)
    quote_id = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn.to_i).order('created_at DESC').pluck(:id).last
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    quote_details = nil
    details = PropertyDetails.details(@udprn)['_source']
    property_status_type = Trackers::Buyers::PROPERTY_STATUS_TYPES[details['_source']['property_status_type']]
    if quote_id
      quote_details = Agents::Branches::AssignedAgents::Quote.create!(
        quote_id: quote_id,
        payment_terms: payment_terms,
        services_required: services_required,
        status: new_status,
        quote_details: quote_details,
        is_assigned_agent: assigned_agent,
        property_status_type: property_status_type,
        agent_id: agent_id
      )
    end
    return { message: 'Quote successfully submitted', quote: quote_details }, 200
  end

  def new_quote_for_property(services_required, payment_terms, quote_details, assigned_agent)
    deadline = 168.hours.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[services_required]
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    # Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    details = PropertyDetails.details(@udprn)['_source']
    district = details['district']
    property_status_type = Trackers::Buyers::PROPERTY_STATUS_TYPES[details['_source']['property_status_type']]
    quote_details = Agents::Branches::AssignedAgents::Quote.create!(
      deadline: deadline,
      property_id: @udprn,
      property_status_type: property_status_type,
      status: status,
      payment_terms: payment_terms,
      quote_details: quote_details,
      service_required: services_required,
      district: district
    )
    return { message: 'Quote successfully created', quote: quote_details }, 200
  end

  #### TODO: Accepting Quote is racy
  def accept_quote_from_agent(agent_id)
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
    lost_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Lost']
    klass = Agents::Branches::AssignedAgents::Quote
    quote = klass.where(property_id: @udprn.to_i, agent_id: nil).order('created_at DESC').last
    agent_quote = klass.where(property_id: @udprn.to_i, agent_id: agent_id).order('created_at DESC').last
    response = nil
    if quote && quote.status != won_status && agent_quote
      agent_quote.status = won_status
      agent_quote.save!
      quote.destroy!
      klass.where(property_id: @udprn.to_i).where.not(agent_id: agent_id)
           .update_all(status: lost_status)
      client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
      doc = { agent_id: agent_id, agent_status: 2 } #### agent_status = 2(agent is actively attached, agent_status = 1, agent submitting pictures and quote)
      PropertyDetails.update_details(client, @udprn.to_i, doc)
      details = PropertyDetails.details(@udprn.to_i, doc)
      response = { details: details, message: 'The quote is accepted' }
    else
      response = { message: 'Another quote for this property has already been accepted' }
    end
    response
  end

end
