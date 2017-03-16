module AgentsHelper
  def link_agent_hierarchy
    agent = Agents::Branches::AssignedAgent.last
    branch = Agents::Branch.last
    group = Agents::Group.last
    company = Agent.last

    agent.branch_id = branch.id
    branch.agent_id = company.id
    company.group_id = group.id

    agent.save! && branch.save! && group.save! && company.save!
  end
end
