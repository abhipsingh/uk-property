class VendorApi
  attr_accessor :udprn, :branch_id

  INFLATION_RATE = 2.5
  def initialize(udprn, branch_id = nil)
    @udprn ||= udprn
    @branch_id ||= branch_id
  end

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

        inflation_adjusted_price_diff = (detail.price - inflation_adjusted_price).round(2) * 100
        inflation_adjusted_price_diff_percent = ((inflation_adjusted_price_diff.to_f)/(last_price_paid.to_f)).round(2)
      end
      sale_info.push({index: index, date: Date.parse(detail.date).to_formatted_s(:long), price_paid: detail.price, price_diff: price_diff_last, price_diff_percent: price_diff_last_percent, inflation_adjusted_price: inflation_adjusted_price, inflation_adjusted_price_diff: inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent: inflation_adjusted_price_diff_percent})
    end



    last_sale_info = sale_info.last
    if sale_info.count > 0
      date = "Upto #{(Time.now.year)-1}"
      price_diff_last, price_diff_last_percent, inflation_adjusted_price, inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent = nil
      if sale_info.first[:price_paid] && sale_info.first[:date]
        price_diff_last = sale_info.last[:price_paid] - sale_info.first[:price_paid]
        price_diff_last_percent = ((price_diff_last.to_f / sale_info.first[:price_paid].to_f)).round(2)*100
        first_date = Date.parse(sale_info.first[:date])
        year_diff = (Time.now.year - 1) - first_date.year
        inflation_adjusted_price = (calculate_compounded_rate(sale_info.first[:price_paid], year_diff)).round(2)

        inflation_adjusted_price_diff = (sale_info.last[:price_paid] - inflation_adjusted_price).round(2)*100
        inflation_adjusted_price_diff_percent = ((inflation_adjusted_price_diff.to_f)/(sale_info.last[:price_paid].to_f)).round(2)*100
      end
      sale_info.push({index: (sale_info.count +1), date: date, price_paid: sale_info.last[:price_paid], price_diff: price_diff_last, price_diff_percent: price_diff_last_percent, inflation_adjusted_price: inflation_adjusted_price, inflation_adjusted_price_diff: inflation_adjusted_price_diff, inflation_adjusted_price_diff_percent: inflation_adjusted_price_diff_percent})
    end
    property = Oj.load(Net::HTTP.get(URI.parse("http://localhost:9200/addresses/address/#{@udprn}")))
    property = property['_source'] if property.has_key?('_source')
    dream_price = property['dream_price'].to_f
    current_valuation = property['valuations'].last.to_f rescue nil

    dream_price_info = calculate_price_info(dream_price, sale_info.last, sale_info.first)
    valuation_info = calculate_price_info(current_valuation, sale_info.last, sale_info.first)
    {sale_info: sale_info, dream_price_info: dream_price_info, valuation_info: valuation_info}
  end

  def calculate_quotes
    quotes = []
    TempPropertyDetail.where(udprn: udprn).limit(5).each do |detail|
      if detail.agent_id
        agent_api = AgentApi.new(detail.agent_id, udprn)
        quotes.push(agent_api.calculate_quotes)
      end
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
    if sale_info
      {
        price: price,
        inflation_price: sale_info[:inflation_adjusted_price],
        inflation_price_diff:   (price.to_f - sale_info[:inflation_adjusted_price].to_f),
        inflation_price_diff_percent:   ((price.to_f - sale_info[:inflation_adjusted_price].to_f)/(sale_info[:inflation_adjusted_price].to_f)).round(2)*100,
        last_sale_price: sale_info[:price_paid],
        last_sale_price_diff: price - sale_info[:price_paid],
        last_sale_price_diff_percent: ((price - sale_info[:price_paid])/sale_info[:price_paid]).round(2)*100,
        first_sale_price: first_sale_info[:price_paid],
        first_sale_price_diff: price - first_sale_info[:price_paid],
        first_sale_price_diff_percent: ((price - first_sale_info[:price_paid])/first_sale_info[:price_paid]).round(2)*100,
      }
    end
  end


end


