class QuoteService
  attr_accessor :udprn, :quote

  def initialize(udprn)
    @udprn = udprn
  end

  def submit_price_for_quote(agent_id, payment_terms, quote_details, services_required, terms_url)
    first_quote = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn.to_i, expired: false, parent_quote_id: nil).order('created_at desc').select([:id, :amount, :existing_agent_id]).first
    quote_amount = first_quote.amount
    quote_id = first_quote.id
    new_status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required]
    services_required = eval(services_required.to_s)
    details = PropertyDetails.details(@udprn)[:_source]
    vendor = Vendor.find(details[:vendor_id])
    property_status_type = Event::PROPERTY_STATUS_TYPES[details['property_status_type']]
    if quote_id
      quote_details = Agents::Branches::AssignedAgents::Quote.create!(
        payment_terms: payment_terms,
        service_required: services_required,
        status: new_status,
        quote_details: quote_details,
        property_id: @udprn.to_i,
        district: details[:district],
        property_status_type: property_status_type,
        agent_id: agent_id,
        vendor_id: vendor.id,
        vendor_name: vendor.name,
        vendor_email: vendor.email,
        vendor_mobile: vendor.mobile,
        terms_url: terms_url,
        parent_quote_id: quote_id,
        amount: quote_amount,
        existing_agent_id: first_quote.existing_agent_id
      )
      @quote = quote_details

      ### Send email to the vendor
      AgentQuoteNotifyVendorWorker.perform_async(@quote.id)

    end
    return { message: 'Quote successfully submitted', quote: quote_details }, 200
  end

  def edit_quote_details(agent_id, payment_terms, quote_details, services_required, terms_url)
    quote = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id, property_id: @udprn.to_i, expired: false).order('created_at DESC').first
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required] if services_required
    services_required = eval(services_required.to_s) if services_required
    if quote
      quote.payment_terms = payment_terms
      quote.service_required = services_required
      quote.quote_details = quote_details if quote_details
      quote.terms_url = terms_url if terms_url
    end
    quote.save!
    return { message: 'Quote successfully submitted', quote: quote_details }, 200
  end

  def new_quote_for_property(services_required, payment_terms, quote_details, assigned_agent, existing_agent_id)
    deadline = Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME.from_now.to_s
    services_required = Agents::Branches::AssignedAgents::Quote::REVERSE_SERVICES_REQUIRED_HASH[services_required]
    services_required = eval(services_required.to_s)
    status = Agents::Branches::AssignedAgents::Quote::STATUS_HASH['New']
    # Rails.logger.info("QUOTE_DETAILS_#{quote_details}")
    details = PropertyDetails.details(@udprn)[:_source]
    district = details['district']
    vendor = Vendor.find(details[:vendor_id])
    property_status_type = Event::PROPERTY_STATUS_TYPES[details['property_status_type']]
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
      vendor_id: vendor.id,
      vendor_name: vendor.name,
      vendor_email: vendor.email,
      vendor_mobile: vendor.mobile,
      amount: details[:current_valuation].to_i,
      existing_agent_id: existing_agent_id.to_i
    )

    ### Send email to all local agents
    VendorQuoteAgentNotifyWorker.perform_async(quote.id)

    return { message: 'Quote successfully created', quote: quote }, 200
  end

  #### TODO: Accepting Quote is racy
  def accept_quote_from_agent(agent_id, agent_quote)
    klass = Agents::Branches::AssignedAgents::Quote
    new_status = klass::STATUS_HASH['New']
    won_status = klass::STATUS_HASH['Won']
    lost_status = klass::STATUS_HASH['Lost']
    response = nil
    agent = Agents::Branches::AssignedAgent.find(agent_id)
    quote = klass.where(id: agent_quote.parent_quote_id, parent_quote_id: nil).last
    Rails.logger.info("#{quote.id}__#{agent_quote.id}__#{agent_id}")
    if quote && quote.status != won_status && agent_quote && agent
      parent_quote_id = quote.id
      quote.destroy!
      agent_quote.status = won_status
      agent_quote.parent_quote_id = nil
      agent_quote.save!
      klass.where(property_id: @udprn.to_i, parent_quote_id: parent_quote_id).where.not(agent_id: agent_id).update_all(status: lost_status, parent_quote_id: agent_quote.id)

      ### Attach the agent to the property and tag the property
      ### enquiries to the agent
      doc = { agent_id: agent_id, agent_status: 2, property_status_type: 'Green' } #### agent_status = 2(agent is actively attached, agent_status = 1, agent submitting pictures and quote)
      PropertyService.new(@udprn.to_i).update_details(doc)
      Event.where(udprn: @udprn).unscope(where: :is_archived).update_all(agent_id: agent_id)

      details = PropertyDetails.details(@udprn.to_i)

      ### Refund the credits of other agents
      QuoteRefundWorker.perform_async(@udprn.to_i, agent_quote.id)

      response = { details: details, message: 'The quote is accepted' }
    else
      response = { message: 'Another quote for this property has already been accepted' }
    end
    response
  end

end

