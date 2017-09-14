
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
    branch_name = branch.name
    aggregate_stats[:branch_id] = branch.id
    calculate_aggregate_stats(aggregate_stats)

    all_agents_in_branch = Agents::Branches::AssignedAgent.where(branch_id: @branch_id).pluck(:id).uniq
    all_agents_in_branch.map{ |t| calculate_per_property_stats_for_agent(property_quotes)}

    { name: branch_name, id: branch_id, aggregate_stats: aggregate_stats, property_quotes: property_quotes }
  end

  #### This function computes the aggregate quote stats for the agent.
  #### AgentApi.new(10966139, 1234).calculate_aggregate_stats({})
  def calculate_aggregate_stats(aggregate_stats)
    all_valuations =  all_valuations_of_agent
    all_agents_in_branch = Agents::Branches::AssignedAgent.where(branch_id: @branch_id).pluck(:id).uniq
    all_agents_result = all_agents_in_branch.map { |e|  all_sales_of_agent(e) }.flatten!
    aggregate_stats[:aggregate_sales] = all_agents_result.map{|t| t.sale_price }.reduce(&:+)

    all_agents_result = all_agents_in_branch.map { |e| average_no_of_days_to_sell(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:avg_no_of_days_to_sell] = (all_agents_result.reduce(:+).to_i/all_agents_result.count.to_f)

    all_agents_result = all_agents_in_branch.map { |e| average_no_of_days_to_sell(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:percent_more_than_valuation] = (all_agents_result.reduce(:+).to_f/all_agents_result.count.to_f)
    # aggregate_stats[:avg_valuation] = ((all_valuations.map{|t| t[:no_of_valuations] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)*100
    # aggregate_stats[:avg_greater_than_valuation] = percent_more_than_valuation
    all_agents_result = all_agents_in_branch.map { |e| avg_changes_to_valuation(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:avg_changes_to_valuation] = (all_agents_result.reduce(:+).to_f/all_agents_result.count.to_f)
    
    all_agents_result = all_agents_in_branch.map { |e| avg_increase_in_value(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:avg_increase_in_valuation] = (all_agents_result.reduce(:+).to_f/all_agents_result.count.to_f)
    
    all_agents_result = all_agents_in_branch.map { |e| avg_percent_of_first_valuation_achieved(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:avg_percent_of_first_valuation] = (all_agents_result.reduce(:+).to_f/all_agents_result.count.to_f)

    all_agents_result = all_agents_in_branch.map { |e| avg_percent_of_final_valuation_achieved(e) }
    all_agents_result = all_agents_result.select{|t| t>0}
    aggregate_stats[:avg_percent_of_final_valuation] = (all_agents_result.reduce(:+).to_f/all_agents_result.count.to_f)
    
    aggregate_stats[:pay_link] = 'Random link'
    aggregate_stats[:quote_price] = quote_price
    quote = Agents::Branches::AssignedAgents::Quote.where(property_id: @udprn).last
    aggregate_stats[:payment_terms] = nil
    aggregate_stats[:payment_terms] = quote.payment_terms if quote
    aggregate_stats[:quote_details] = quote.quote_details if quote
    # aggregate_stats[:avg_final_valuation_percent] = ((quotes.map{|t| t[:final_valuation_percent] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)
    # aggregate_stats[:avg_first_valuation_percent] = ((quotes.map{|t| t[:first_valuation_percent] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)
  end

  def calculate_sale_detail(udprn)
    property = Oj.load(Net::HTTP.get(URI.parse("http://localhost:9200/addresses/address/#{udprn}")))
    property = property['_source'] if property.has_key?('_source')
    # branch_index = property['branch_ids'].find_index(@branch_id)
    valuations = property['valuations']
    final_sale_price = property['final_sale_price']
    result_hash = {}
    result_hash[:first_valuation] = valuations[0]
    result_hash[:second_valuation] = valuations[1]
    result_hash[:third_valuation] = valuations[2]
    final_valuation = valuations.compact.last
    result_hash[:final_sale_price] = final_sale_price
    result_hash[:no_of_valuations] = valuations.compact.count
    result_hash[:greater_than_valuation] = (final_valuation > final_sale_price) ? 0 : 1
    result_hash[:increase_in_valuation] = ((((final_sale_price - valuations.first).to_f)/((valuations.first).to_f))*100).round(2)
    result_hash[:final_valuation_percent] = (((final_sale_price).to_f / (final_valuation).to_f)*100).round(2)
    result_hash[:first_valuation_percent] = (((final_sale_price).to_f / (valuations.first).to_f)*100).round(2)
    result_hash
  end

  def calculate_percent_increase_in_valuation(valuation, final_sale_price)
    if (valuation > final_sale_price)
      0
    else
      1
    end
  end

  def recent_quotes
  end

  #### To test this function run in the console
  #### AgentApi.new(10966139, 1234).number_of_properties_sold
  #### TODO: Fix me, after changing the event storage layer to propertyevent, this is obsolete
  def number_of_properties_sold(agent_id=nil)
    agent_id ||= @agent_id
    SoldProperty.where(agent_id: agent_id).count
  end

  #### To test this function run in the console
  #### AgentApi.new(10966139, 1234).all_valuations_of_agent
  #### TODO: Fix me, after changing the event storage layer to propertyevent, this is obsolete
  def all_valuations_of_agent(agent_id=nil)
    valuations = []
    event = Trackers::Buyer::EVENTS[:valuation_change]
    agent_id ||= @agent_id
    api = PropertySearchApi.new(filtered_params: { agent_id: agent_id })
    api.apply_filters
    udprns, status = api.fetch_udprns
    udprns.map { |e| valuations.push(PropertyEvent.where(udprn: e).where("attr_hash ? 'current_valuation'").order('created_at DESC'))) }
    valuations
  end

  #### To test this function run in the console
  #### AgentApi.new(10966139, 1234).all_sales_of_agent
  #### TODO: Fix me, after changing the event storage layer to propertyevent, this is obsolete
  def all_sales_of_agent(agent_id=nil)
    agent_id ||= @agent_id
    SoldProperty.where(agent_id: agent_id).order('created_at DESC').count
  end

  #### To test this function run in the console
  #### AgentApi.new(10966139, 1234).average_no_of_days_to_sell
  #### Agents::Branches::AssignedAgents::Quote.create(deadline: Time.now, status: 1, property_id: 10976765, agent_id: 1234, created_at: 32.days.ago)
  #### Agents::Branches::AssignedAgents::Quote.create(deadline: Time.now, status: 1, property_id: 10975337, agent_id: 1234, created_at: 28.days.ago)
  #### Agents::Branches::AssignedAgents::Quote.create(deadline: Time.now, status: 1, property_id: 54042234, agent_id: 1234, created_at: 30.days.ago)
  #### TODO: Fix me. Agent can be tagged in many ways to the property, not just quotes
  def average_no_of_days_to_sell(agent_id=nil)
    agent_id ||= @agent_id
    all_sales = all_sales_of_agent(agent_id)
    total_time_diff = 0
    count = 0
    all_sales.each do |each_sale|
      start_dates = Agents::Branches::AssignedAgents::Quote.where(property_id: each_sale.udprn).where(agent_id: agent_id).where(status: 3).pluck(:updated_at).last
      if start_date
        end_date = each_sale.created_at
        time_diff = (end_date - start_date).to_i/(24 * 60 * 60)
        total_time_diff += time_diff
        count += 1
      end
    end
    if count > 0
      (total_time_diff/count).floor
    else
      -1
    end
  end

  #### How many properties were sold by the agent which exceeded the current_valuation
  #### AgentApi.new(10966139, 1234).percent_more_than_valuation
  def percent_more_than_valuation(agent_id=nil)
    agent_id ||= @agent_id
    all_sales = all_sales_of_agent(agent_id)
    all_valuations = all_valuations_of_agent(agent_id)
    valuation_property_hash = {}
    all_valuations.each do |each_property_valuation|
      message = each_property_valuation.first.attr_hash
      valuation = message['current_valuation'].to_i
      valuation_property_hash[each_property_valuation.first.udprn] = valuation       
    end

    count = 0
    greater_count = 0
    all_sales.each do |each_sale|
      count += 1 
      final_price = each_sale.sale_price
      valuation_price = valuation_property_hash[each_sale.udprn]
       if valuation_price && final_price >= valuation_price
         greater_count += 1
       end
    end

    if count > 0
      (greater_count/count).to_i * 100
    else
      -1
    end
  end

  #### How many properties were sold by the agent which exceeded the current_valuation
  #### AgentApi.new(10966139, 1234).avg_changes_to_valuation
  def avg_changes_to_valuation(agent_id=nil)
    agent_id ||= @agent_id
    count = 0
    all_valuations = all_valuations_of_agent(agent_id)
    all_valuations.each do |each_property_valuation|
      count += each_property_valuation.count
    end

    if count > 0
      (count/all_valuations.count).round(2)
    else
      -1
    end
  end

  #### How many properties were sold by the agent which exceeded the current_valuation
  #### AgentApi.new(10966139, 1234).avg_increase_in_value
  def avg_increase_in_value(agent_id=nil)
    agent_id ||= @agent_id
    all_valuations = all_valuations_of_agent(agent_id)
    valuation_property_hash = {}

    all_valuations.each do |each_property_valuation|
      message = each_property_valuation.first.attr_hash
      valuation = message['current_valuation']
      valuation_property_hash[each_property_valuation.first.udprn] = valuation
    end

    sum_of_percentage_changes = 0

    count = 0
    all_sales = all_sales_of_agent(agent_id)
    all_sales.each do |each_sale|
      count += 1
      final_price = each_sale.sale_price
      valuation = valuation_property_hash[each_sale.udprn]
      sum_of_percentage_changes += (((final_price - valuation).to_f/(valuation.to_f)) * 100).round(2)
    end

    if count > 0
      (sum_of_percentage_changes/count).round(2)
    else
      -1
    end

  end

  #### What is the average percentage of first valuation achieved
  #### AgentApi.new(10966139, 1234).avg_percent_of_first_valuation_achieved
  def avg_percent_of_first_valuation_achieved(agent_id=nil)
    agent_id ||= @agent_id
    all_valuations = all_valuations_of_agent(agent_id)
    valuation_property_hash = {}

    all_valuations.each do |each_property_valuation|
      message = each_property_valuation.last.attr_hash
      valuation = message['current_valuation']
      valuation_property_hash[each_property_valuation.first.udprn] = valuation
    end

    sum_of_percentage_changes = 0

    count = 0
    all_sales = all_sales_of_agent(agent_id)
    all_sales.each do |each_sale|
      count += 1
      final_price = each_sale.sale_price
      valuation = valuation_property_hash[each_sale.udprn]
      sum_of_percentage_changes += (((final_price).to_f/(valuation.to_f)) * 100).round(2)
    end

    if count > 0
      (sum_of_percentage_changes/count).round(2)
    else
      -1
    end

  end

  #### What is the average percentage of final valuation achieved
  #### AgentApi.new(10966139, 1234).avg_percent_of_final_valuation_achieved
  def avg_percent_of_final_valuation_achieved(agent_id=nil)
    agent_id ||= @agent_id
    all_valuations = all_valuations_of_agent(agent_id)
    valuation_property_hash = {}

    all_valuations.each do |each_property_valuation|
      message = each_property_valuation.first.attr_hash
      valuation = message['current_valuation']
      valuation_property_hash[each_property_valuation.first.udprn] = valuation
    end

    sum_of_percentage_changes = 0

    count = 0
    all_sales = all_sales_of_agent(agent_id)
    all_sales.each do |each_sale|
      count += 1
      final_price = each_sale.sale_price
      valuation = valuation_property_hash[each_sale.udprn]
      sum_of_percentage_changes += (((final_price).to_f/(valuation.to_f)) * 100).round(2)
    end

    if count > 0
      (sum_of_percentage_changes/count).round(2)
    else
      -1
    end

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
