class ModifyIsDeveloperInAgentsBranch < ActiveRecord::Migration
  def change
    remove_column(:agents_branches, :is_developer)
    add_column(:agents_branches, :is_developer, :boolean, default: false)
  end
end

