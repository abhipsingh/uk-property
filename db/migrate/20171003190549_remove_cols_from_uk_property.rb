class RemoveColsFromUkProperty < ActiveRecord::Migration
  def change
    remove_column(:uk_properties, :post_town)
    remove_column(:uk_properties, :dl)
    rename_column(:uk_properties, :parsed_post_town, :post_town)
    rename_column(:uk_properties, :parsed_dl, :dl)
  end
end
