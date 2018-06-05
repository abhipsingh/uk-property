class AddAgentIdToAddressDistrictRegister < ActiveRecord::Migration
  def change
    add_column(:address_district_registers, :agent_id, :integer)
    add_index(:address_district_registers, :agent_id, name: 'preemptions_agents_idx')
  end
end

