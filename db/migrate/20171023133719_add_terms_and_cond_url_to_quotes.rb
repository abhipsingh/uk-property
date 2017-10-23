class AddTermsAndCondUrlToQuotes < ActiveRecord::Migration
  def change
    add_column(:agents_branches_assigned_agents_quotes, :term_url, :string)
  end
end

