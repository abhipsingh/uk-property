class AddLockedFlagAndLockedDateToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :locked, :boolean, default: false)
    add_column(:agents_branches, :locked_date, :date)
  end
end
