class AddBudgetFromAndToPropertyBuyers < ActiveRecord::Migration
  def change
    add_column(:property_buyers, :budget_from, :integer)
    add_column(:property_buyers, :budget_to, :integer)
  end
end
