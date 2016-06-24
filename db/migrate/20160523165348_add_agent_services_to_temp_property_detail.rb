class AddAgentServicesToTempPropertyDetail < ActiveRecord::Migration
  def change
    add_column(:temp_property_details, :agent_services, :jsonb)
  end
end
