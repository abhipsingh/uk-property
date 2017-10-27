class QuoteService

  attr_accessor :udprn

  def initialize(udprn)
    @udprn = udprn
  end

  def submit_price_for_quote(agent_id, payment_terms, quote_details, services_required, terms_url)
    quote_id = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn.to_i).order('created_at DESC').pluck(:id).last
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required]
    services_required = eval(services_required.to_s)
    details = PropertyDetails.details(@udprn)[:_source]
    vendor = Vendor.find(details[:vendor_id])
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    if quote_id
      quote_details = Agents::Branches::AssignedAgents::Quote.create!(
        payment_terms: payment_terms,
        service_required: services_required,
        status: new_status,
        quote_details: quote_details,
        property_id: @udprn.to_i,
        property_status_type: property_status_type,
        agent_id: agent_id,
        vendor_name: vendor.name,
        vendor_email: vendor.email,
        vendor_mobile: vendor.mobile,
        terms_url: terms_url
      )
    end
    return { message: 'Quote successfully submitted', quote: quote_details }, 200
  end

  def edit_quote_details(agent_id, payment_terms, quote_details, services_required, terms_url)
    quote = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, property_id: @udprn.to_i).order('created_at DESC').pluck(:id).last
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required] if services_required
    services_required = eval(services_required.to_s) if services_required
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    if quote
      quote.payment_terms = payment_terms
      quote.service_required = service_required
      quote.quote_details = quote_details if quote_details
      quote.terms_url = terms_url if terms_url
    end
    return { message: 'Quote successfully submitted', quote: quote_details }, 200
  end

  def new_quote_for_property(services_required, payment_terms, quote_details, assigned_agent)
    deadline = 168.hours.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required]
    services_required = eval(services_required.to_s)
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    # Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    details = PropertyDetails.details(@udprn)[:_source]
    district = details['district']
    vendor = Vendor.find(details[:vendor_id])
    property_status_type = Trackers::Buyer::PROPERTY_STATUS_TYPES[details['property_status_type']]
    quote = Agents::Branches::AssignedAgents::Quote.create!(
      deadline: deadline,
      property_id: @udprn,
      property_status_type: property_status_type,
      status: status,
      payment_terms: payment_terms,
      quote_details: quote_details,
      is_assigned_agent: assigned_agent,
      service_required: services_required,
      district: district,
      vendor_name: vendor.name,
      vendor_email: vendor.email,
      vendor_mobile: vendor.mobile
    )
    return { message: 'Quote successfully created', quote: quote }, 200
  end

  #### TODO: Accepting Quote is racy
  def accept_quote_from_agent(agent_id)
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    won_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Won']
    lost_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['Lost']
    klass = Agents::Branches::AssignedAgents::Quote
    quote = klass.where(property_id: @udprn.to_i, agent_id: nil).order('created_at DESC').last
    agent_quote = klass.where(property_id: @udprn.to_i, agent_id: agent_id).order('created_at DESC').last
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
    response = nil
    if quote && quote.status != won_status && agent_quote && agent
      quote.destroy!
      agent_quote.status = won_status
      agent_quote.save!
      client = Elasticsearch::Client.new host: Rails.configuration.remote_es_host
      doc = { agent_id: agent_id, agent_status: 2, property_status_type: 'Green' } #### agent_status = 2(agent is actively attached, agent_status = 1, agent submitting pictures and quote)
      PropertyDetails.update_details(client, @udprn.to_i, doc)
      details = PropertyDetails.details(@udprn.to_i)

      ### Deduct agents credits
      agent.credit = agent.credit - 5
      agent.save!
      response = { details: details, message: 'The quote is accepted' }
    else
      response = { message: 'Another quote for this property has already been accepted' }
    end
    response
  end

end
