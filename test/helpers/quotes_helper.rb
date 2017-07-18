module QuotesHelper
  include EsHelper
  SAMPLE_SERVICES_REQUIRED = 'Fixed Price'
  SAMPLE_PAYMENT_TERMS = 'Pay upfront'
  SAMPLE_QUOTE_DETAILS = { "fixed_price_services_requested" => { "price" => nil, "list_of_services" => [{'type' => "Full", 'price'=>nil}] } }

  def new_quote_for_property(id)
    service = QuoteService.new(id)
    response = service.new_quote_for_property(SAMPLE_SERVICES_REQUIRED, SAMPLE_PAYMENT_TERMS,
                                              SAMPLE_QUOTE_DETAILS, false)
    # post "/quotes/property/#{id}", params: hash_val
    # assert_response 200
    doc = get_es_address(id)
    last_quote = Agents::Branches::AssignedAgents::Quote.last
    last_quote.district = doc['_source']['district']
    last_quote.save!
  end


  def new_quote_by_agent(id, agent_id)
    service = QuoteService.new(id)
    doc = get_es_address(id)
    quote_details = Agents::Branches::AssignedAgents::Quote.where(property_id: id, agent_id: nil).last.quote_details
    quote_details['fixed_price_services_requested']['list_of_services'][0]['price'] = 1200
    response = service.submit_price_for_quote(agent_id, SAMPLE_PAYMENT_TERMS, 
                                              quote_details, 
                                              SAMPLE_SERVICES_REQUIRED)
  end

  def accept_quote_from_agent(id, agent_id)
    service = QuoteService.new(id)
    service.accept_quote_from_agent(agent_id)
  end
end
