class AgentsController < ApplicationController
	### Details of the branch
	### curl -XGET 'http://localhost/agents/predictions?str=Dyn'
  def search
    klasses = ['Agent', 'Agents::Branch', 'Agents::Group', 'Agents::Branches::AssignedAgent']
    search_results = klasses.map { |e|  e.constantize.where("lower(name) LIKE ?", "#{params[:str].downcase}%").limit(10).as_json }
    results = []
    search_results.each_with_index do |result, index|
    	new_row = {}
    	new_row[:type] = klasses[index]
    	new_row[:result] = result
    	results.push(new_row)
    end
    render json: results, status: 200
  end

	def quotes_per_property
	  quotes = AgentApi.new(params[:property_id].to_i, params[:agent_id].to_i).calculate_quotes
	  render json: quotes, status: 200
	end

	### Details of the agent
	### curl -XGET 'http://localhost/agents/assigned_agent/1234'
	def assigned_agent_details
		assigned_agent_id = params[:assigned_agent_id]
		agent_details = Agents::Branches::AssignedAgent.find(assigned_agent_id).as_json(include: [:active_properties])
		render json: agent_details, status: 200
	end

	### Details of the branch
	### curl -XGET 'http://localhost/agents/branch/9851'
	def branch_details
		branch_id = params[:branch_id]
		branch = Agents::Branch.find(branch_id)
		branch_details = branch.as_json(include: {assigned_agents: {include: [:active_properties]}})
		render json: branch_details, status: 200
  end

  ### Details of the company
  ### curl -XGET 'http://localhost/agents/agent/6290'
  def agent_details
		agent_id = params[:agent_id]
		agent = Agent.find(agent_id)
		agent_details = agent.as_json(include:  { branches: { include: { assigned_agents: {include: [:active_properties]}}}})
		render json: agent_details, status: 200
  end

  ### Details of the group
  ### curl -XGET 'http://localhost/agents/group/1'
  def group_details
		group_id = params[:group_id]
		group = Agents::Group.find(group_id)
		group_details = group.as_json(include:  { agents: { include: { branches: { include: { assigned_agents: {include: [:active_properties]}}}}}})
		render json: group_details, status: 200
  end

end
