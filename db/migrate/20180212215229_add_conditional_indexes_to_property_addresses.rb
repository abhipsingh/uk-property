class AddConditionalIndexesToPropertyAddresses < ActiveRecord::Migration
  def up
    post_towns = [0, 29, 69, 89, 115, 123, 190, 195, 247, 279, 318, 362, 392, 393, 491, 588, 607, 724, 753, 832, 841, 855, 872, 906, 913, 924, 935, 1010, 1059, 1107, 1111, 1149, 1153, 1157, 1211, 1235, 1245, 1273, 1425, 1452, 1468, 1472]
    post_towns.each do |post_town|
      execute("CREATE INDEX pa_pt_#{post_town}_idx ON property_addresses(dl, td, dtd) WHERE pt=#{post_town}")
    end
  end

  def down
    post_towns = [0, 29, 69, 89, 115, 123, 190, 195, 247, 279, 318, 362, 392, 393, 491, 588, 607, 724, 753, 832, 841, 855, 872, 906, 913, 924, 935, 1010, 1059, 1107, 1111, 1149, 1153, 1157, 1211, 1235, 1245, 1273, 1425, 1452, 1468, 1472]
    post_towns.each do |post_town|
      execute("DROP INDEX pa_pt_#{post_town}_idx")
    end
  end
end
