class AddPoBoxTypeToUkProperty < ActiveRecord::Migration
  def change
    add_column(:uk_properties, :parsed_post_town, :string)
    add_column(:uk_properties, :po_box_no, :string)
    add_column(:uk_properties, :parsed_dl, :string)
    change_column(:uk_properties, :county, :string, limit: 30)
    remove_column(:uk_properties, :created_at)
    remove_column(:uk_properties, :updated_at)
  end
end
