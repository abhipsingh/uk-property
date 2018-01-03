class CreatePostCodes < ActiveRecord::Migration
  def change
    create_table :post_codes do |t|
      t.float :lat
      t.float :long
      t.string :postcode
    end
  end
end
