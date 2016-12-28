class AgentsController < ApplicationController
	### Details of the branch
	### curl -XGET 'http://localhost/agents/predictions?str=Dyn'
  def search
    klasses = ['Agent', 'Agents::Branch', 'Agents::Group', 'Agents::Branches::AssignedAgent']
    klass_map = {
    	'Agent' => 'Company',
    	'Agents::Branch' => 'Branch',
    	'Agents::Group' => 'Group',
    	'Agents::Branches::AssignedAgent' => 'Agent'
    }
    search_results = klasses.map { |e|  e.constantize.where("lower(name) LIKE ?", "#{params[:str].downcase}%").limit(10).as_json }
    results = []
    search_results.each_with_index do |result, index|
    	new_row = {}
    	new_row[:type] = klass_map[klasses[index]]
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
	### curl -XGET 'http://localhost/agents/agent/1234'
	def assigned_agent_details
		assigned_agent_id = params[:assigned_agent_id]
		assigned_agent = Agents::Branches::AssignedAgent.find(assigned_agent_id)
		agent_details = assigned_agent.as_json(methods: [:active_properties])
		agent_details[:company_id] = assigned_agent.branch.agent_id
		agent_details[:group_id] = assigned_agent.branch.agent.group_id
		render json: agent_details, status: 200
	end

	### Details of the branch
	### curl -XGET 'http://localhost/agents/branch/9851'
	def branch_details
		branch_id = params[:branch_id]
		branch = Agents::Branch.find(branch_id)
		branch_details = branch.as_json(include: {assigned_agents: {methods: [:active_properties]}})
		branch_details[:company_id] = branch.agent_id
		branch_details[:group_id] = branch.agent.group.id
		render json: branch_details, status: 200
  end

  ### Details of the company
  ### curl -XGET 'http://localhost/agents/company/6290'
  def agent_details
		agent_id = params[:agent_id]
		agent = Agent.find(agent_id)
		agent_details = agent.as_json(include:  { branches: { include: { assigned_agents: {methods: [:active_properties]}}}})
		render json: agent_details, status: 200
  end

  ### Details of the group
  ### curl -XGET 'http://localhost/agents/group/1'
  def group_details
		group_id = params[:group_id]
		group = Agents::Group.find(group_id)
		group_details = group.as_json(include:  { agents: { include: { branches: { include: { assigned_agents: {methods: [:active_properties]}}}}}})
		render json: group_details, status: 200
  end

  ### Add new agent details to exisiting or create a new agent
  ### agent_id is null or not null depending upon if its a new agent or not
  ### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/register' -d '{"agent_id" : null, "branch_id" : 9851, "company_id" : 6290, "group_id" : 1, "group_name" :"Dynamic Group", "company_name" : "Dynamic Property Management", "branch_name" : "Dynamic Property Management", "branch_address" : "18 Hope Street, Crook, DL15 9HS", "branch_phone_number" : "9988776655", "branch_email" : "df@fg.com", "branch_website" : "www.dmg.com", "agent_name" : "Jacqueline Bing" ,"agent_email" : "jackbing@dmg.com", "agent_mobile_number" : "9988776655" }'
  def add_agent_details
  	agent_id = params[:agent_id].to_i
  	agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
  	if agent
  		branch_id = agent.branch_id
  	else
  		branch_id = params[:branch_id]
  	end
		agent = Agents::Branches::AssignedAgent.new unless agent
  	agent.name = params[:agent_name]
  	agent.email = params[:agent_email]
  	agent.mobile = params[:agent_mobile_number]
  	agent.branch_id = branch_id
  	branch = agent.branch
  	company = branch.agent
  	group = company.group
  	branch.name = params[:branch_name]
  	branch.address = params[:branch_address]
  	branch.email = params[:branch_email]
  	branch.phone_number = params[:branch_phone_number]
  	branch.website = params[:branch_website]
  	group.name = params[:group_name]
  	company.name = params[:company_name]

  	if agent.save && company.save && group.save && branch.save
  		render json: { message: 'Agent saved successfully', details: agent }, status: 201
  	else
  		render json: { message: 'Agent not saved successfully', details: agent }, status: 400
  	end

	end

	#### Invite the other agents to register
	#### curl -XPOST -H "Content-Type: application/json" 'http://localhost/agents/invite' -d '{"agent_id" : 1234, "invited_agents" : "\[ \{ \"branch_id\" : 9851, \"company_id\" : 6290, \"email\" : \"a@b.com\" \} , \{ \"branch_id\" : 9851, \"company_id\" : 6290,\"email\" : \"b@c.com\" \} ]" }'
	def invite_agents_to_register
		agent_id = params[:agent_id].to_i
  	agent = Agents::Branches::AssignedAgent.where(id: agent_id).last
		if agent
			other_agents = params[:invited_agents]
			agent.invited_agents = JSON.parse(other_agents)
			if agent.save
				render json: { message: 'Agents with given emails invited' }, status: 200
			else
				render json: { message: 'Server error' }, status: 400
			end
		else
			render json: { message: 'Agent with given agent_id doesnt exist' }, status: 400
		end
	end

end
