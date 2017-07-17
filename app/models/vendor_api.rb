class VendorApi
  attr_accessor :udprn, :branch_id, :agent_id, :vendor_id

  ### TODO: Put this in a config
  INFLATION_RATE = 2.5

  def initialize(udprn, branch_id = nil, vendor_id=nil)
    @udprn ||= udprn
    @branch_id ||= branch_id
    @vendor_id ||= vendor_id
  end

  #### Called by the pricing api to fetch pricing information about the udprn
  #### Example VendorApi.new('10966139').calculate_valuations
  #### TODO: remove udprn hardcoding
  def calculate_valuations
    historical_details = PropertyHistoricalDetail.where(udprn: @udprn).order(:date)
    sale_info = []
    historical_details.each_with_index do |detail, index|
      price_diff_last, price_diff_last_percent, inflation_adjusted_price, inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent = nil
      if sale_info.last && sale_info.last[:price_paid] && sale_info.last[:date]
        last_price_paid = sale_info.last[:price_paid]
        price_diff_last = detail.price - last_price_paid
        price_diff_last_percent = ((price_diff_last.to_f / last_price_paid.to_f)).round(2)*100
        last_date = Date.parse(sale_info.last[:date])
        current_date = Date.parse(detail.date)
        year_diff = current_date.year - last_date.year
        inflation_adjusted_price = calculate_compounded_rate(last_price_paid, year_diff).round(2)

        inflation_adjusted_price_diff = (detail.price - inflation_adjusted_price).round(4)
        inflation_adjusted_price_diff_percent = ((((inflation_adjusted_price_diff.to_f)/(last_price_paid.to_f)))*100).round(2)
      end
      sale_info.push({index: index, date: Date.parse(detail.date).to_formatted_s(:long), price_paid: detail.price, price_diff: price_diff_last, price_diff_percent: price_diff_last_percent, inflation_adjusted_price: inflation_adjusted_price, inflation_adjusted_price_diff: inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent: inflation_adjusted_price_diff_percent})
    end



    last_sale_info = sale_info.last
    if sale_info.count > 0
      date = "Upto #{(Time.now.year)}"
      price_diff_last, price_diff_last_percent, inflation_adjusted_price, inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent = nil
      if sale_info.first[:price_paid] && sale_info.first[:date]
        price_diff_last = sale_info.last[:price_paid] - sale_info.first[:price_paid]
        price_diff_last_percent = ((price_diff_last.to_f / sale_info.first[:price_paid].to_f)).round(2)*100
        first_date = Date.parse(sale_info.first[:date])
        year_diff = (Time.now.year - 1) - first_date.year
        inflation_adjusted_price = (calculate_compounded_rate(sale_info.first[:price_paid], year_diff)).round(2)

        inflation_adjusted_price_diff = (sale_info.last[:price_paid] - inflation_adjusted_price).round(4)
        inflation_adjusted_price_diff_percent = (((inflation_adjusted_price_diff.to_f)/(sale_info.last[:price_paid].to_f))*100).round(2)
      end
      sale_info.push({index: (sale_info.count +1), date: date, price_paid: sale_info.last[:price_paid], price_diff: price_diff_last, price_diff_percent: price_diff_last_percent, inflation_adjusted_price: inflation_adjusted_price, inflation_adjusted_price_diff: inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent: inflation_adjusted_price_diff_percent})
    end

    ### Dream price compute
    property = PropertyDetails.details(@udprn)
    dream_price = property['_source']['dream_price'].to_f rescue -1.0

    ### Current valuation compute
    current_valuation = nil
    event = Trackers::Buyer::EVENTS[:valuation_change]
    valuation = Event.where(event: event).where(udprn: @udprn).order('created_at DESC').limit(1).first
    current_valuation = valuation['current_valuation'] if valuation

    dream_price_info = calculate_price_info(dream_price, sale_info.last, sale_info.first)
    valuation_info = calculate_price_info(current_valuation, sale_info.last, sale_info.first)
    { sale_info: sale_info, dream_price_info: dream_price_info, valuation_info: valuation_info }
  end

  def calculate_quotes
    quotes = []
    agent_quotes = Agents::Branches::AssignedAgents::SubmiitedQuote.where(property_id: udprn.to_i)
                                                                   .where.not(agent_id: nil)
                                                                   .where.not(agent_id: 1)
                                                                   .where('created_at > ?', 1.week.ago).order('created_at DESC').limit(2)
    agent_quotes.each do |agent_quote|
      agent_id = agent_quote.agent_id
      ### TODO: Remove this
      if agent_id != 1
        agent_api = AgentApi.new(udprn, agent_id)
        quotes.push(agent_api.calculate_quotes)
        
      end
    end
    quotes = quotes.uniq{ |t| t['id'] }
  end

  def calculate_compounded_rate(base_price, years)
    new_price = base_price.to_f
    years.times do
      new_price += ((INFLATION_RATE/ 100.0)* new_price)
    end
    new_price
  end

  def calculate_price_info(price, sale_info, first_sale_info)
    if price && sale_info && sale_info[:price_paid] && first_sale_info[:price_paid]
      {
        price: price,
        inflation_price: sale_info[:inflation_adjusted_price],
        inflation_price_diff:   (price.to_f - sale_info[:inflation_adjusted_price].to_f),
        inflation_price_diff_percent:  (((price.to_f - sale_info[:inflation_adjusted_price].to_f)/(sale_info[:inflation_adjusted_price].to_f))*100).round(2),
        last_sale_price: sale_info[:price_paid],
        last_sale_price_diff: price - sale_info[:price_paid],
        last_sale_price_diff_percent: ((((price - sale_info[:price_paid]).to_f)/sale_info[:price_paid].to_f)*100).round(2),
        first_sale_price: first_sale_info[:price_paid],
        first_sale_price_diff: price - first_sale_info[:price_paid],
        first_sale_price_diff_percent: ((((price - first_sale_info[:price_paid]).to_f)/first_sale_info[:price_paid].to_f)*100).round(2),
      }
    end
  end

  def properties_sold(agent_id)
    self.class.all_sales_of_agent(agent_id).count
  end

  #### To test this function run in the console
  #### VendorApi.all_valuations_of_agent(1234)
  def self.all_valuations_of_agent(agent_id)
    valuations = []
    event = Trackers::Buyer::EVENTS[:valuation_change]
    udprns = Event.where(agent_id: agent_id).where(event: event).pluck(:udprn).uniq
    udprns.map { |e| valuations.push(Event.where(agent_id: @agent_id).where(event: event).where(udprn: e).order('created_at DESC')) }
    valuations
  end

  #### To test this function run in the console
  #### VendorApi.all_sales_of_agent(1234)
  def self.all_sales_of_agent(agent_id)
    event = Trackers::Buyer::EVENTS[:sold]
    Event.where(agent_id: agent_id).where(event: event).order('created_at DESC')
  end

  #### Collects all the details of the property owned by the vendor
  #### VendorApi.new(10966139, nil, 1).property_details
  def property_details
    details = PropertyDetails.details(@udprn)['_source']
    details['address'] = PropertyDetails.address(details)

    ### Historical detail
    historical_detail = PropertyHistoricalDetail.where(udprn: udprn.to_s).order('date DESC').limit(1).first
    details['last_sale_price'] = nil
    details['last_sale_price'] = historical_detail.price if historical_detail
    details['last_sale_price_date'] = nil
    details['last_sale_price_date'] = historical_detail.date if historical_detail

    #### Agent details
    agent_id = details['agent_id']
    agent = Agents::Branches::AssignedAgent.where(id: agent_id).first
    agent_keys = ['assigned_agent_name', 'assigned_agent_branch_name', 'assigned_agent_company_name', 'assigned_agent_group_name',
                  'assigned_agent_image_url', 'assigned_agent_mobile', 'assigned_agent_email', 'assigned_agent_office_number',
                  'assigned_agent_branch_address', 'assigned_agent_branch_number', 'assigned_agent_branch_logo', 'assigned_agent_branch_email',
                  'branch_properties_sold', 'branch_properties_on_sale']
    agent_keys.each{ |t| details[t] = nil }
    if agent
      details['assigned_agent_name'] = agent.name
      details['assigned_agent_branch_name'] = agent.branch.name
      details['assigned_agent_company_name'] = agent.branch.agent.name
      details['assigned_agent_group_name'] = agent.branch.agent.group.name
      details['assigned_agent_image_url'] = agent.image_url
      details['assigned_agent_mobile'] = agent.mobile
      details['assigned_agent_email'] = agent.email
      details['assigned_agent_office_number'] = agent.office_phone_number
      details['assigned_agent_branch_address'] = agent.branch.address
      details['assigned_agent_branch_number'] = agent.branch.phone_number
      details['assigned_agent_branch_logo'] = agent.branch.image_url
      details['assigned_agent_branch_email'] = agent.branch.email

      ### No of properties sold for this branch
      event = Trackers::Buyer::EVENTS[:sold]
      agent_ids = Agents::Branches::AssignedAgent.find(agent_id).branch.assigned_agents.pluck(:id)
      sold_udprns = Event.where(event: event).where(agent_id: agent_ids).pluck(:udprn)
      details['branch_properties_sold'] = sold_udprns.count

      #### No of properties on sale
      total_udprns = Event.where.not(event: event).where(agent_id: agent_ids).pluck(:udprn)
      details['branch_properties_on_sale'] = (total_udprns.uniq - sold_udprns).count
    end
   

    ### Advertised or not
    details['advertised'] = details['match_type_str'].any? { |e| ['Featured', 'Premium'].include?(e.split('|').last) }
    
    ### Extra keys to be added
    table = nil
    property_id = @udprn
    details['total_visits'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:visits], table, property_id, :single)
    details['total_enquiries'] =Trackers::Buyer.new. generic_event_count(Trackers::Buyer::ENQUIRY_EVENTS, table, property_id, :multiple)
    details['total_interested_in_viewing'] =Trackers::Buyer.new. generic_event_count(Trackers::Buyer::EVENTS[:interested_in_viewing], table, property_id, :single)
    details['total_interested_in_making_an_offer'] =Trackers::Buyer.new. generic_event_count(Trackers::Buyer::EVENTS[:interested_in_making_an_offer], table, property_id, :single)
    details['trackings'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::TRACKING_EVENTS, table, property_id, :multiple)
    details['requested_viewing'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:requested_viewing], table, property_id, :single)
    details['offer_made_stage'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:offer_made_stage], table, property_id, :single)
    details['requested_message'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:requested_message], table, property_id, :single)
    details['requested_callback'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:requested_callback], table, property_id, :single)
    # new_row['impressions'] = generic_event_count(:impressions, table, property_id, :single)
    details['deleted'] = Trackers::Buyer.new.generic_event_count(Trackers::Buyer::EVENTS[:deleted], table, property_id, :single)

    details
  end

end

