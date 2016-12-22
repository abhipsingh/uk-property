class AddImageUrlToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :image_url, :string)
  end
end
