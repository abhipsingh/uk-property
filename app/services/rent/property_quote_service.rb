module Rent
  class PropertyQuoteService
    
    attr_accessor :udprn
    S3_BASE_URL = "https://s3.#{ENV['S3_REGION']}.amazonaws.com/#{ENV['S3_STREET_VIEW_BUCKET']}/"
  
    def initialize(udprn: property_id)
      @udprn = udprn
    end

    def submit_price_for_quote(agent_id, payment_terms, quote_price, terms_url)
      first_quote = Rent::Quote.where(udprn: @udprn.to_i, expired: false).order('created_at desc').limit(1).select([:id]).first
      price = quote_price
      quote_id = first_quote.id
      new_status = Rent::Quote::STATUS_HASH['New']
      payment_terms = Rent::Quote::PAYMENT_TERMS_HASH[payment_terms]
      details = PropertyDetails.details(@udprn)[:_source]
      vendor = Vendor.find(details[:vendor_id])
      if quote_id
        quote_details = Rent::Quote.create!(
          payment_terms: payment_terms,
          status: new_status,
          udprn: @udprn.to_i,
          district: details[:district],
          agent_id: agent_id,
          vendor_id: vendor.id,
          terms_url: terms_url,
          parent_quote_id: quote_id,
          price: quote_price
        )
        @quote = quote_details
      end
      return { message: 'Quote successfully submitted', quote: quote_details }, 200
    end

    def edit_quote_details(agent_id, payment_terms=nil, quote_price=nil, terms_url=nil)
      quote = Rent::Quote.where(agent_id: agent_id, udprn: @udprn.to_i, expired: false)
                         .order('created_at DESC')
                         .limit(1).first
      payment_terms = Rent::Quote::PAYMENT_TERMS_HASH[payment_terms] if payment_terms
      if quote
        quote.payment_terms = payment_terms
        quote.price = quote_price if quote_price
        quote.terms_url = terms_url if terms_url
      end
      quote.save!
      return { message: 'Quote successfully submitted', quote: quote }, 200
    end

    def new_quote_for_property(assigned_agent, agent_id, district, vendor_id)
      status = Rent::Quote::STATUS_HASH['New']
      is_assigned_agent = (assigned_agent.to_s == 'true')
      quote = Rent::Quote.create!(
        status: status,
        udprn: @udprn.to_i,
        is_assigned_agent: is_assigned_agent,
        payment_terms: 0,
        district: district,
        vendor_id: vendor_id,
        existing_agent_id: agent_id
      )
      return { message: 'Quote successfully created', quote: quote }, 200
    end

    #### TODO: Accepting Quote is racy
    def accept_quote_from_agent(quote, parent_quote)
      klass = Rent::Quote
      new_status = klass::STATUS_HASH['New']
      won_status = klass::STATUS_HASH['Won']
      lost_status = klass::STATUS_HASH['Lost']
      agent_quote = quote
      quote = parent_quote
      response = nil
      agent_id = agent_quote.agent_id
      if quote && quote.status != won_status && agent_quote
        quote.destroy!
        agent_quote.status = won_status
        agent_quote.parent_quote_id = nil
        agent_quote.save!
        klass.where(udprn: @udprn.to_i, parent_quote_id: parent_quote.id).update_all(status: lost_status, parent_quote_id: agent_quote.id)

        ### Attach the agent to the property and tag the property
        ### enquiries to the agent
        doc = { lettings: true }
        PropertyService.new(@udprn.to_i).update_details(doc)
        Event.where(udprn: @udprn).unscope(where: :is_archived).update_all(agent_id: agent_id)

        details = PropertyDetails.details(@udprn.to_i)

        ### Refund the credits of other agents
        #RentQuoteRefundWorker.perform_async(@udprn.to_i, agent_quote.id)

        response = { details: details, message: 'The quote is accepted' }
      else
        response = { message: 'Another quote for this property has already been accepted' }
      end
      response
    end

    def agent_quotes
      klass = Rent::Quote

      new_status = klass::STATUS_HASH['New']

      all_agent_quotes = []
      vendor_quote = klass.where(expired: false).where(agent_id: nil).where(udprn: @udprn.to_i).where.not(vendor_id: nil).order('created_at DESC').limit(1).first
      if vendor_quote
        quotes_from_agents = klass.where(status: new_status)
                                  .where.not(agent_id: nil)
                                  .where(udprn: @udprn.to_i)
                                  .where(expired: false)
                                  .where(parent_quote_id: vendor_quote.id)
                                  .where('created_at >= ?', vendor_quote.created_at)
                                  .where('created_at < ?', vendor_quote.created_at + klass::MAX_VENDOR_QUOTE_WAIT_TIME)
        ### Fetch in bulk both agents and branch details
        agent_ids = quotes_from_agents.map(&:agent_id)
        agent_details = Agents::Branches::AssignedAgent.where(id: agent_ids).select([:id, :image_url, :first_name, :last_name, :branch_id, :email, :mobile, :office_phone_number, :title])
        branch_ids = agent_details.map(&:branch_id)
        branch_details = Agents::Branch.where(id: branch_ids).select([:id, :image_url, :name,:address, :website, :phone_number])

        agent_details_hash = agent_details.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.id => hash)}
        branch_details_hash = branch_details.reduce({}) { |acc_hash, hash| acc_hash.merge(hash.id => hash)}

        quotes_from_agents.each do |each_agent_quote|
          
          agent_api = AgentApi.new(@udprn.to_i, each_agent_quote.agent_id.to_i)
          aggregate_stats = {}
          agent_api.populate_aggregate_stats(aggregate_stats)
          aggregate_stats[:quote_id] = each_agent_quote.id
          aggregate_stats[:quote_price] = each_agent_quote.price
          aggregate_stats[:payment_terms] = Rent::Quote::REVERSE_PAYMENT_TERMS_HASH[each_agent_quote.payment_terms]
          aggregate_stats[:deadline_start] = Time.parse((vendor_quote.created_at + klass::MAX_AGENT_QUOTE_WAIT_TIME).to_s).strftime("%Y-%m-%dT%H:%M:%SZ")
          aggregate_stats[:deadline_end] = Time.parse((vendor_quote.created_at + klass::MAX_VENDOR_QUOTE_WAIT_TIME).to_s).strftime("%Y-%m-%dT%H:%M:%SZ")
          aggregate_stats[:terms_url] = each_agent_quote.terms_url
          aggregate_stats[:agent_id] = each_agent_quote.agent_id

          agent_detail = agent_details_hash[each_agent_quote.agent_id]
          branch_detail = branch_details_hash[agent_detail.branch_id]
          aggregate_stats[:assigned_agent_first_name] = agent_detail.first_name
          aggregate_stats[:assigned_agent_mobile] = agent_detail.mobile
          aggregate_stats[:assigned_agent_office_number] = agent_detail.office_phone_number
          aggregate_stats[:assigned_agent_title] = agent_detail.title
          aggregate_stats[:assigned_agent_last_name] = agent_detail.last_name
          aggregate_stats[:assigned_agent_image_url] = agent_detail.image_url
          aggregate_stats[:assigned_agent_email] = agent_detail.email
          aggregate_stats[:branch_name] = branch_detail.name
          aggregate_stats[:branch_address] = branch_detail.address
          aggregate_stats[:branch_phone_number] = branch_detail.phone_number
          aggregate_stats[:branch_website] = branch_detail.website
          aggregate_stats[:branch_id] = agent_detail.branch_id
          aggregate_stats[:branch_logo] = branch_detail.image_url
          all_agent_quotes.push(aggregate_stats)

        end
        #### End of do bloack

      end
      ### End of if bloack
      all_agent_quotes

    end

    ####   End of method ####

  end
end

