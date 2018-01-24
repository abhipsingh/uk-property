class AddIndexToBranchIdInCrawledProperties < ActiveRecord::Migration
  def up
    execute('CREATE INDEX crawled_properties_branches_idx ON agents_branches_crawled_properties (branch_id)')
  end

  def down
    execute('DROP INDEX crawled_properties_branches_idx ON agents_branches_crawled_properties (branch_id)')
  end
end
