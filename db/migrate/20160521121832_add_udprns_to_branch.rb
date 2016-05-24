class AddUdprnsToBranch < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :udprns, :text, array: true, default: [])
  end
end
