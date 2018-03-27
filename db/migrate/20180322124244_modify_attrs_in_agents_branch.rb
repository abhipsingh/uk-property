class ModifyAttrsInAgentsBranch < ActiveRecord::Migration
  def change
    remove_column(:agents_branches, :locked)
    remove_column(:agents_branches, :locked_date)
  end
end
