class AddValidationToInvitedAgent < ActiveRecord::Migration
  def change
    change_column(:invited_agents, :email, :string, null: false)
  end
end
