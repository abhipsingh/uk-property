class AddReadyForLaunchToAgentCompany < ActiveRecord::Migration
  def change
    add_column(:agents, :is_ready_for_launch, :boolean, default: false)
  end
end
