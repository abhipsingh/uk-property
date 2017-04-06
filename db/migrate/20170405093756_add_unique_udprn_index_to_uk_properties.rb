class AddUniqueUdprnIndexToUkProperties < ActiveRecord::Migration
  def change
    add_index(:uk_properties, :udprn, { unique: true })
  end
end
