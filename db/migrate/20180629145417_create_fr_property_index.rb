class CreateFrPropertyIndex < ActiveRecord::Migration
  def up
    remove_column(:fr_properties, :udprn, :string)
    add_column(:fr_properties, :udprn, :integer)
  end

  def down
    remove_column(:fr_properties, :udprn, :integer)
    add_column(:fr_properties, :udprn, :string)
  end

end

