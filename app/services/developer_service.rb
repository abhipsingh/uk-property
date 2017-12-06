class DeveloperService

  attr_accessor :developer_id

  def initialize(developer_id)
    @developer_id = developer_id
  end

  def upload_property_details(property_attrs, assigned_developer_email, branch_id, developer_id)
    if property_attrs[:udprn]
      branch = Agents::Branch.unscope(where: :is_developer).where(is_developer: true, id: branch_id).last
      invited_agents = branch.invited_agents
      branch.invited_agents = [ { 'email' => assigned_developer_email, 'udprn' => property_attrs[:udprn], 'entity_id' => developer_id } ]
      branch.send_emails(true)
      branch.invited_agents += invited_agents
      branch.save!
      property_attrs[:assigned_agent_email] = assigned_developer_email
      property_service = PropertyService.new(property_attrs[:udprn].to_i)
      property_service.update_details(property_attrs)
    else
      return { message: 'Field udprn not found' }, 400
    end
  end

end
