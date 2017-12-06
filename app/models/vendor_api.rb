class VendorApi
  attr_accessor :udprn, :branch_id, :agent_id, :vendor_id

  ### TODO: Put this in a config
  INFLATION_RATE = 2.5

  def initialize(udprn, branch_id = nil, vendor_id=nil)
    @udprn ||= udprn
    @branch_id ||= branch_id
    @vendor_id ||= vendor_id
  end

  def calculate_quotes
    quotes = []
    agent_quotes = Agents::Branches::AssignedAgents::Quote.where(property_id: udprn.to_i)
                                                          .where.not(agent_id: nil)
                                                          .where.not(agent_id: 1)
                                                          .where('created_at > ?', 4.week.ago)
                                                          .order('created_at DESC')
                                                          .limit(2)
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
end

