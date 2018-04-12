class AgentApi
  attr_accessor :branch_id, :udprn, :details, :vendor_quote, :agent

  def initialize(udprn, agent_id)
    @udprn ||= udprn
    @agent_id ||= agent_id
  end

  #### To calculate the detailed quotes for each of the agent, we can call this function
  #### Below is an example of how it can be tested in the irb
  ####  AgentApi.new(10966139).calculate_quotes
  def calculate_quotes(vendor_quote, agent_quote)
    aggregate_stats = {}
    property_quotes = {}
    agent = Agents::Branches::AssignedAgent.find(@agent_id)
    branch = agent.branch
    branch_id = branch.id
    branch_name = branch.name
    result = { id: @agent_id  }
    result[:branch_id] = branch.id
    result[:branch_logo] = branch.image_url
    result[:branch_address] = branch.address
    result[:branch_name] = branch.name
    result[:branch_phone_number] = branch.phone_number
    result[:branch_website] = branch.website
    calculate_aggregate_stats(result, branch_id, vendor_quote, agent_quote)

    result[:assigned_agent_first_name] = agent.first_name
    result[:assigned_agent_last_name] = agent.last_name
    result[:assigned_agent_image_url] = agent.image_url
    result[:assigned_agent_mobile] = agent.mobile
    result[:assigned_agent_email] = agent.email
    result[:assigned_agent_title] = agent.title
    result
  end

  #### This function computes the aggregate quote stats for the agent.
  #### AgentApi.new(10966139, 1234).calculate_aggregate_stats({})
  def calculate_aggregate_stats(aggregate_stats, branch_id, vendor_quote, agent_quote)
    all_agents_in_branch = Agents::Branches::AssignedAgent.where(branch_id: branch_id).pluck(:id).uniq
    populate_aggregate_stats(aggregate_stats)
    aggregate_stats[:pay_link] = 'Random link'
    aggregate_stats[:quote_price] = quote_price
    quote = agent_quote
    aggregate_stats[:payment_terms] = nil
    aggregate_stats[:payment_terms] = quote.payment_terms if quote
    aggregate_stats[:quote_details] = quote.quote_details if quote
    aggregate_stats[:deadline_start] = Time.parse((vendor_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_AGENT_QUOTE_WAIT_TIME).to_s).strftime("%Y-%m-%dT%H:%M:%SZ") if quote
    aggregate_stats[:deadline_end] = Time.parse((vendor_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME).to_s).strftime("%Y-%m-%dT%H:%M:%SZ") if quote
    aggregate_stats[:deadline] = Time.parse((vendor_quote.created_at + Agents::Branches::AssignedAgents::Quote::MAX_VENDOR_QUOTE_WAIT_TIME).to_s).strftime("%Y-%m-%dT%H:%M:%SZ") if quote
    aggregate_stats[:terms_url] = quote.terms_url if quote
    aggregate_stats[:services_required] = Agents::Branches::AssignedAgents::Quote::SERVICES_REQUIRED_HASH[quote.service_required.to_s.to_sym] if quote
    aggregate_stats
  end

  def populate_aggregate_stats(aggregate_stats)
    sold_properties = SoldProperty.where(agent_id: @agent_id).select([:sale_price, :completion_date, :udprn, :completion_date]).to_a
    valuation_events = PropertyEvent.where(agent_id: @agent_id).where("attr_hash ? 'current_valuation'")
                                    .select(:udprn)
                                    .select("string_agg((attr_hash ->> 'current_valuation')::text, '|') as current_valuation")
                                    .select("string_agg(date(created_at)::text, '|') as date")
                                    .group(:udprn)
    all_property_count = PropertyEvent.where(agent_id: @agent_id).count

    
    ### Calculate agent properties
    statuses = ['Green', 'Red' , 'Amber']
    all_counts = {}
    statuses.each do |status|
      search_params = { agent_id: @agent_id.to_i, property_search_type: status }
      api = PropertySearchApi.new(filtered_params: search_params)
      count, status = api.matching_property_count
      all_counts[status] = count if status.to_i == 200
    end
    
    ### Calculate current valuations of all agent properties
    search_params = { agent_id: @agent_id.to_i, results_per_page: 200 }
    api = PropertySearchApi.new(filtered_params: search_params)
    api.modify_query
    api.apply_filters
    udprns, status = api.fetch_udprns
    udprns ||= []
    Rails.logger.info(udprns)
    aggregate_valuation = udprns.inject(0){|sum, udprn| PropertyDetails.details(udprn)[:_source][:current_valuation].to_i + sum }

    sold_property_count = sold_properties.count
    sold_property_map = {}
    all_sold_udprns = []
    sold_properties.each do |each_prop|
      sold_property = PropertyEvent.where(agent_id: @agent_id).where(udprn: each_prop.udprn).where("(attr_hash ? 'price') OR (attr_hash ? 'sale_price')").order('created_at asc').limit(1).first #### There might be multiple times an agent can be attached to this property TODO
      sale_price = sold_property.attr_hash['sale_price'] || sold_property.attr_hash['price']  if sold_property
      sale_price ||= 0

      sold_property_map[each_prop.udprn] = each_prop
      all_sold_udprns.push(each_prop.udprn)
    end

    agent_events = PropertyEvent.where(agent_id: @agent_id).where(udprn: all_sold_udprns).group(:udprn).select('min(created_at) as first_date').select(:udprn)
    last_property_status_types = []
    udprn_property_status_type_agent_attached_date_map = {}
    udprn_agent_attached_date_map = {}
    agent_events.each do |each_event|
      last_property_status_type = PropertyEvent.where(udprn: each_event.udprn).where("attr_hash ? 'property_status_type'").order('created_at desc').limit(1).select("attr_hash ? 'property_status_type' as property_status_type").last
      last_property_status_types.push(last_property_status_type)
      udprn_property_status_type_agent_attached_date_map[last_property_status_type.property_status_type] ||= []
      property_status_type = last_property_status_type.property_status_type
      udprn_hash = { udprn: each_event.udprn, created_at: each_event.first_date, property_status_type: property_status_type }
      udprn_property_status_type_agent_attached_date_map[property_status_type].push(udprn_hash)
      udprn_agent_attached_date_map[each_event.udprn] = udprn_hash
    end

    aggregate_sales = sold_properties.map{|t| t.sale_price }.reduce(:+)
    total_days_to_sell = nil
    achieved_more_than_valuation_count = 0
    changes_to_valuation = 0
    percent_of_first_valuation = 0
    percent_of_last_valuation = 0
    total_days_to_sell_map = {}
    valuation_events.each do |each_udprn|
      valuations = each_udprn.current_valuation.split('|') 
      
      last_valuation = nil
      duplicate_indexes = []
      duplicate_indexes = valuations.each_with_index do |curr_valuation, index|
        if curr_valuation != last_valuation
          curr_valuation = last_valuation
        else
          duplicate_indexes.push(index)
          next
        end
      end

      dates = each_udprn.date.split('|').map{|t| Date.parse(t)}
      modified_dates = []

      dates.each_with_index do |each_date, index|
        modified_dates.push(each_date) if !duplicate_indexes.include?(index)
      end

      dates = modified_dates

      sold_property_data = [ sold_property_map[each_udprn.udprn] ].compact
      sold_property_data ||= []
      sold_property_data.each do |each_sold_prop_data|
        total_days_to_sell ||= 1
        total_days_to_sell_map[udprn_agent_attached_date_map[each_sold_prop_data.udprn][:property_status_type]] ||= []
        total_days_to_sell_map[udprn_agent_attached_date_map[each_sold_prop_data.udprn][:property_status_type]].push(each_sold_prop_data.completion_date - udprn_agent_attached_date_map[each_sold_prop_data.udprn][:created_at].to_date)

        ### for finding first and last valuation
        first_valuation_index = dates.index(dates.sort.first)
        last_valuation_index = dates.index(dates.sort.last)
        achieved_more_than_valuation_count += 1 if each_sold_prop_data.sale_price > valuations[first_valuation_index].to_i
        
        ### for calculating avg change in valuation
        changes_to_valuation += last_valuation_index - first_valuation_index

        ### for calculating percent of first valuation
        percent_of_first_valuation += ((valuations[first_valuation_index].to_f/each_sold_prop_data.sale_price.to_f)*100).round(2)

      end
    end
    total_days_to_sell_map['Green'] ||= []
    total_days_to_sell_map['Red'] ||= []
    total_days_to_sell_map['Amber'] ||= []
    avg_no_of_days_to_sell_green = ((total_days_to_sell_map['Green'].sum.to_f/total_days_to_sell_map['Green'].count.to_f)*100).round(2)
    avg_no_of_days_to_sell_amber_red = (((total_days_to_sell_map['Red'].sum.to_f + total_days_to_sell_map['Amber'].sum.to_f)/(total_days_to_sell_map['Amber'].count.to_f + total_days_to_sell_map['Red'].count.to_f))*100).round(2)
    avg_achieved_more_than_valuation_count = ((achieved_more_than_valuation_count.to_f/sold_property_count.to_f)*100).round(2)
    avg_changes_to_valuation = (changes_to_valuation.to_f/sold_property_count.to_f).round(2)
    percent_of_first_valuation = (percent_of_first_valuation.to_f/sold_property_count.to_f).round(2)

    ### All stats for agents quotes
    aggregate_stats[:total_count] = all_counts['Green'].to_i + all_counts['Red'].to_i + all_counts['Amber'].to_i
    aggregate_stats[:aggregate_valuation] = aggregate_valuation
    aggregate_stats[:avg_no_of_days_to_sell_green] = avg_no_of_days_to_sell_green.nan? ? nil : avg_no_of_days_to_sell_green
    aggregate_stats[:avg_no_of_days_to_sell_amber_red] = avg_no_of_days_to_sell_amber_red.nan? ? nil : avg_no_of_days_to_sell_amber_red
    aggregate_stats[:aggregate_valuation] = aggregate_valuation
    aggregate_stats[:green_property_count] = all_counts['Green'].to_i
    aggregate_stats[:amber_red_property_count] = all_counts['Red'].to_i + all_counts['Amber'].to_i
    aggregate_stats[:for_sale] = aggregate_stats[:green_property_count]
    aggregate_stats[:sold] = sold_property_count
    aggregate_stats[:aggregate_sales] = aggregate_sales
    aggregate_stats[:avg_achieved_more_than_valuation_count] = (avg_achieved_more_than_valuation_count.nan? ? nil : avg_achieved_more_than_valuation_count)
    aggregate_stats[:avg_changes_to_valuation] = (avg_changes_to_valuation.nan? ? nil : avg_changes_to_valuation)
    aggregate_stats[:avg_percent_of_first_valuation] = (percent_of_first_valuation.nan? ? nil : percent_of_first_valuation)
  end

  #### Final aggregated quote price of the agent
  #### AgentApi.new(10966139, 1234).quote_price
  def quote_price(agent_id=nil)
    agent_id ||= @agent_id
    quote = Agents::Branches::AssignedAgents::Quote.where(agent_id: agent_id).where(property_id: @udprn).order('created_at DESC').first
    price = nil
    if quote
      price = quote.compute_price
    end
    price.to_i
  end
end

