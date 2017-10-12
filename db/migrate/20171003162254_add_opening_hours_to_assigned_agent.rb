class AddOpeningHoursToAssignedAgent < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :opening_hours, :jsonb)
  end
end
