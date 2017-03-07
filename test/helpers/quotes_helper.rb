module QuotesHelper
  SAMPLE_SERVICES_REQUIRED = 'Fixed Price'
  SAMPLE_PAYMENT_TERMS = 'Pay upfront'
  SAMPLE_QUOTE_DETAILS = { "fixed_price_services_requested" => { "price" => nil, "list_of_services" => ["Full"] } }

  def new_quote_for_property(id)
    service = QuoteService.new(id)
    response = service.new_quote_for_property(SAMPLE_SERVICES_REQUIRED, SAMPLE_PAYMENT_TERMS,
                                              SAMPLE_QUOTE_DETAILS.to_json, false)
    # post "/quotes/property/#{id}", params: hash_val
    # assert_response 200
  end


  def new_quote_by_agent(id, agent_id)
    service = QuoteService.new(id)
    SAMPLE_QUOTE_DETAILS['fixed_price_services_requested']['price'] = 1200
    response = service.submit_price_for_quote(agent_id, SAMPLE_PAYMENT_TERMS, 
                                              SAMPLE_QUOTE_DETAILS.to_json, 
                                              SAMPLE_SERVICES_REQUIRED)
  end

  def accept_quote_from_agent(id, agent_id)
    service = QuoteService.new(id)
    service.accept_quote_from_agent(agent_id)
  end
end
