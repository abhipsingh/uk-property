class AgentApi
  attr_accessor :branch_id, :udprn

  def initialize(branch_id, udprn)
    @branch_id ||= branch_id
    @udprn ||= udprn
  end

  def calculate_quotes
    udprns = TempPropertyDetail.where(agent_id: branch_id).select([:udprn, :agent_id])
    property_quotes = []
    udprns.each_with_index do |udprn_inner, index|
      if udprn.to_i != udprn_inner.udprn.to_i
        hash = {index: index, branch_id: udprn_inner.agent_id}
        result_hash = calculate_sale_detail(udprn_inner.udprn)
        result_hash = result_hash.merge(hash)
        property_quotes.push(result_hash)
      end
    end
    aggregate_stats = {}
    branch = Agents::Branch.find(branch_id)
    branch_name = branch.name
    aggregate_stats[:branch_id] = branch.id
    calculate_aggregate_stats(property_quotes, aggregate_stats)
    { name: branch_name, id: branch_id, aggregate_stats: aggregate_stats, property_quotes: property_quotes }
  end

  def calculate_aggregate_stats(quotes, aggregate_stats)
    aggregate_stats[:sales] = quotes.map{|t| t[:final_sale_price] }.reduce(&:+)
    aggregate_stats[:avg_valuation] = ((quotes.map{|t| t[:no_of_valuations] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)*100
    aggregate_stats[:avg_greater_than_valuation] = ((quotes.map{|t| t[:greater_than_valuation] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(4)
    aggregate_stats[:avg_increase_in_valuation] = ((quotes.map{|t| t[:increase_in_valuation] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(4)
    aggregate_stats[:avg_final_valuation_percent] = ((quotes.map{|t| t[:final_valuation_percent] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)
    aggregate_stats[:avg_first_valuation_percent] = ((quotes.map{|t| t[:first_valuation_percent] }.reduce(&:+).to_f)/(quotes.count.to_f)).round(2)
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

end