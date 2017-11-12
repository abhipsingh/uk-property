module BranchEmailSender
  def self.send_emails_to_branches
    Agents::Branch.where("district LIKE 'L%'").each do |branch|
      email = branch.email
      invited_agents = {}
      invited_agents['email'] = email
      invited_agents['branch_id'] = branch.id
      invited_agents['company_id'] = branch.agent_id
      branch_invited_agents = branch.invited_agents
      branch.save
      branch.send_emails
      branch_invited_agents ||= []
      branch.invited_agents = branch_invited_agents + [ invited_agents ]
      branch.save
    end
  end
end
