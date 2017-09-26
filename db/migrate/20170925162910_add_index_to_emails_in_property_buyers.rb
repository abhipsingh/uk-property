class AddIndexToEmailsInPropertyBuyers < ActiveRecord::Migration
  def up
    execute("CREATE INDEX property_buyers_email_idx ON property_buyers (email text_pattern_ops)")
  end

  def down
    execute("DROP INDEX property_buyers_email_idx")
  end
end
