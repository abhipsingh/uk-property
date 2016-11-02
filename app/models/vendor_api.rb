class VendorApi
  attr_accessor :udprn, :branch_id, :agent_id

  INFLATION_RATE = 2.5
  def initialize(udprn, branch_id = nil)
    @udprn ||= udprn
    @branch_id ||= branch_id
  end

  def self.cassandra_session
    Rails.configuration.cassandra_session
  end

  #### Called by the pricing api to fetch pricing information about the udprn
  #### Example VendorApi.new('10966139').calculate_valuations
  #### TODO remove udprn hardcoding
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
    cql = "SELECT message FROM Simple.timestamped_property_events WHERE event = #{event} AND property_id='10977419' ALLOW FILTERING;" #### TODO Remove udprn hardcoding
    session = Trackers::Buyer.session
    future = session.execute(cql)

    last_row = future.rows.sort_by{ |t| t['time_of_event'] }.last
    if last_row
       current_valuation = JSON.parse(last_row['message'])['current_valuation']
    end

    dream_price_info = calculate_price_info(dream_price, sale_info.last, sale_info.first)
    valuation_info = calculate_price_info(current_valuation, sale_info.last, sale_info.first)
    {sale_info: sale_info, dream_price_info: dream_price_info, valuation_info: valuation_info}
  end

  def calculate_quotes
    quotes = []
    agent_quotes = Agents::Branches::AssignedAgents::Quote.where(property_id: udprn.to_i).where('created_at > ?', 1.week.ago).order('created_at DESC').limit(2)
    agent_quotes.each do |agent_quote|
      agent_id = agent_quote.agent_id
      agent_api = AgentApi.new(agent_id, udprn)
      quotes.push(agent_api.calculate_quotes)
    end
    quotes
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
    session = self.class.cassandra_session
    event = Trackers::Buyer::EVENTS[:sold]
    cql = "SELECT * FROM Simple.timestamped_property_events WHERE agent_id = #{agent_id} AND event = #{event} ALLOW FILTERING "
    future = session.execute(cql)
    count = future.rows.count
  end

  #### To test this function run in the console
  #### VendorApi.all_valuations_of_agent(1234)
  def self.all_valuations_of_agent(agent_id)
    valuations = []
    session = self.class.cassandra_session
    event = Trackers::Buyer::EVENTS[:sold]
    cql = "SELECT * FROM Simple.timestamped_property_events WHERE agent_id = #{agent_id} AND event = #{event} ALLOW FILTERING "
    future = session.execute(cql)
    future.rows.each do |each_row|
      valuations.push(valuations_sorted_by_time(agent_id, each_row['property_id']))
    end
    valuations
  end

  #### To test this function run in the console
  #### VendorApi.all_sales_of_agent(1234)
  def self.all_sales_of_agent(agent_id)
    session = self.class.cassandra_session
    event = Trackers::Buyer::EVENTS[:sold]
    cql = "SELECT * FROM Simple.timestamped_property_events WHERE agent_id = #{agent_id} AND event = #{event} ALLOW FILTERING "
    future = session.execute(cql)
    future.rows.to_a
  end

  #### To test this function run in the console
  #### VendorApi.valuations_sorted_by_time(1234, 10976765)
  def self.valuations_sorted_by_time(agent_id, property_id)
    session = self.class.cassandra_session
    event = Trackers::Buyer::EVENTS[:valuation_change]
    cql = "SELECT * FROM Simple.timestamped_property_events WHERE agent_id = #{agent_id} AND event = #{event} AND property_id = '#{property_id}' ALLOW FILTERING "
    future = session.execute(cql)
    future.rows.sort_by{ |t| t['time_of_event'] }.reverse
  end


end


