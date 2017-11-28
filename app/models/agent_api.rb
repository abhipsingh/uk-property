
class AgentApi
  attr_accessor :branch_id, :udprn, :details

  def initialize(udprn, agent_id)
    @details = PropertyDetails.details(udprn)['_source']
    
    @branch_id ||= Agents::Branches::AssignedAgent.where(id: agent_id).first.branch_id
    @udprn ||= udprn
    @agent_id ||= agent_id
  end

  #### To calculate the detailed quotes for each of the agent, we can call this function
  #### Below is an example of how it can be tested in the irb
  ####  AgentApi.new(10966139).calculate_quotes
  def calculate_quotes
    aggregate_stats = {}
    property_quotes = {}
    branch = Agents::Branch.find(@branch_id)
    agent = Agents::Branches::AssignedAgent.find(@agent_id)
    branch_name = branch.name
    result = { id: @agent_id  }
    result[:branch_id] = branch.id
    result[:branch_logo] = branch.image_url
    calculate_aggregate_stats(result)

    result[:assigned_agent_first_name] = agent.first_name
    result[:assigned_agent_last_name] = agent.last_name
    result[:assigned_agent_image_url] = agent.image_url
    result[:assigned_agent_mobile] = agent.mobile
    result[:assigned_agent_email] = agent.email
    result
  end

  #### This function computes the aggregate quote stats for the agent.
  #### AgentApi.new(10966139, 1234).calculate_aggregate_stats({})
  def calculate_aggregate_stats(aggregate_stats)
    all_agents_in_branch = Agents::Branches::AssignedAgent.where(branch_id: @branch_id).pluck(:id).uniq
    populate_aggregate_stats(aggregate_stats)
    aggregate_stats[:pay_link] = 'Random link'
    aggregate_stats[:quote_price] = quote_price
    quote = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn, agent_id: @agent_id).last
    aggregate_stats[:payment_terms] = nil
    aggregate_stats[:payment_terms] = quote.payment_terms if quote
    aggregate_stats[:quote_details] = quote.quote_details if quote
    aggregate_stats[:deadline] = Time.parse((quote.created_at + 24.hours).to_s).strftime("%Y-%m-%dT%H:%M:%SZ")
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
    sold_property_count = sold_properties.count
    sold_property_map = {}
    avg_increase_in_price = 0
    sold_properties.each do |each_prop|
      sale_price = PropertyEvent.where(agent_id: @agent_id).where(udprn: each_prop.udprn).where("attr_hash ? 'price'").last.price #### There might be multiple times an agent can be attached to this property TODO
      avg_increase_in_price += (((each_prop.sale_price - sale_price).to_f)/(each_prop.sale_price.to_f)*100).round(2)

      sold_property_map[each_prop.udprn] = each_prop
    end

    ### Avg increase in price
    avg_increase_in_price = (avg_increase_in_price.to_f)/(sold_property_count.to_f)

    aggregate_sales = sold_properties.map{|t| t.sale_price }.reduce(:+)
    total_days_to_sell = nil
    achieved_more_than_valuation_count = 0
    changes_to_valuation = 0
    percent_of_first_valuation = 0
    percent_of_last_valuation = 0
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

      sold_property_data = sold_property_map[each_udprn.udprn]
      sold_property_data ||= []
      sold_property_data.each do |each_sold_prop_data|
        total_days_to_sell += each_sold_prop_data.completion_date - dates.sort.first

        ### for finding first and last valuation
        first_valuation_index = dates.index(dates.sort.first)
        last_valuation_index = dates.index(dates.sort.last)
        achieved_more_than_valuation_count += 1 if each_sold_prop_data.sale_price > valuations[first_valuation_index].to_i
        
        ### for calculating avg change in valuation
        changes_to_valuation += last_valuation_index - first_valuation_index

        ### for calculating percent of first valuation
        percent_of_first_valuation += ((valuations[first_valuation_index].to_f/each_sold_prop_data.sale_price.to_f)*100).round(2)

        ### for calculating percent of last valuation
        percent_of_last_valuation += ((valuations[last_valuation_index].to_f/each_sold_prop_data.sale_price.to_f)*100).round(2)

      end
    end

    avg_days_to_sell = (total_days_to_sell.to_f/sold_property_count.to_f).round(1)
    avg_achieved_more_than_valuation_count = ((achieved_more_than_valuation_count.to_f/sold_property_count.to_f)*100).round(2)
    avg_changes_to_valuation = (changes_to_valuation.to_f/sold_property_count.to_f).round(2)
    percent_of_first_valuation = (percent_of_first_valuation.to_f/sold_property_count.to_f).round(2)
    percent_of_last_valuation = (percent_of_last_valuation.to_f/sold_property_count.to_f).round(2)
    
    ### All stats for agents quotes
    aggregate_stats[:for_sale] = all_property_count - sold_property_count
    aggregate_stats[:sold] = sold_property_count
    aggregate_stats[:aggregate_sales] = aggregate_sales
    aggregate_stats[:avg_no_of_days_to_sell] = (avg_days_to_sell.nan? ? nil : avg_days_to_sell)
    aggregate_stats[:avg_achieved_more_than_valuation_count] = (avg_achieved_more_than_valuation_count.nan? ? nil : avg_achieved_more_than_valuation_count)
    aggregate_stats[:avg_changes_to_valuation] = (avg_changes_to_valuation.nan? ? nil : avg_changes_to_valuation)
    aggregate_stats[:avg_increase_in_price] = (avg_increase_in_price.nan? ? nil : avg_increase_in_price)
    aggregate_stats[:avg_percent_of_first_valuation] = (percent_of_first_valuation.nan? ? nil : percent_of_first_valuation)
    aggregate_stats[:avg_percent_of_last_valuation] = (percent_of_last_valuation.nan? ? nil : percent_of_last_valuation)
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

  #### This function gathers all the price movements of all the property
  #### which were handled by this agent.
  #### AgentApi.new(10966139, 1234).avg_percent_of_final_valuation_achieved
  def calculate_all_property_stats_for_agent    
  end


  #### This function gathers all the price movements of a single property
  #### which was handled by this agent
  #### AgentApi.new(10966139, 1234).calculate_per_property_stats_for_agent({})
  #### TODO: Fix me, after changing the event storage layer to propertyevent, this is obsolete
  def calculate_per_property_stats_for_agent(result, agent_id=nil)
    agent_id ||= @agent_id
    all_valuations = all_valuations_of_agent(agent_id)
    all_valuations.each do |each_property_valuation|
      each_property_hash = {}
      event_result = SoldProperty.where(agent_id: agent_id)
      if event_result.count > 0
        ### Property Ids
        property_id = each_property_valuation.first.udprn
        each_property_hash['property_id'] = property_id
        sorted_valuations = each_property_valuation.reverse

        ### First valuation if exists
        each_property_hash['first_valuation'] = sorted_valuations.first.attr_hash['current_valuation'] if each_property_valuation.length > 0
        
        ### Second valuation if exists
        each_property_hash['second_valuation'] = sorted_valuations.second.attr_hash['current_valuation'] if each_property_valuation.length > 1
        
        ### Third valuation if exists
        each_property_hash['third_valuation'] = sorted_valuations.third.attr_hash['current_valuation'] if each_property_valuation.length > 2
    
        ### Final sale price of the property      
        each_property_hash['final_sale_price'] = event_result.first.sale_price


        ### Achieved more than valuation
        final_valuation = each_property_valuation.first.attr_hash['current_valuation']
        cond = nil
        each_property_hash['final_sale_price'] > final_valuation ? cond = 1 : cond = 0
        each_property_hash['achieved_more_than_valuation'] = cond  

        ### Average changes to valuations
        each_property_hash['average_changes_to_valuations'] = each_property_valuation.length

        ### Average increase in valuation
        first_valuation = each_property_valuation.last.attr_hash['current_valuation']
        percent_increase = ((((each_property_hash['final_sale_price'] - first_valuation).to_f)/(first_valuation.to_f)) * 100 ).round(2)
        each_property_hash['percent_increase'] = percent_increase

        ### Percent of first valuation achieved
        percent_first_achieved = (((each_property_hash['final_sale_price'].to_f)/(first_valuation.to_f)) * 100 ).round(2)
        each_property_hash['percent_first_achieved'] = percent_first_achieved

        ### Percent of final valuation achieved
        percent_final_achieved = (((each_property_hash['final_sale_price'].to_f)/(final_valuation.to_f)) * 100 ).round(2)
        each_property_hash['percent_final_achieved'] = percent_final_achieved

        result[property_id] = each_property_hash
      end
    end
    nil
  end

end

