class AddViewingEntityToQuote < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :viewing_entity, :integer, limit: 2)
  end
end

