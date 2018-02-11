class DropTestUkp < ActiveRecord::Migration
  def up
    drop_table(:test_ukps)
  end

  def down
  end
end

