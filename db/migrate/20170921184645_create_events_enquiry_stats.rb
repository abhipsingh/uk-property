class CreateEventsEnquiryStats < ActiveRecord::Migration
  def change
    create_table :events_enquiry_stat_properties do |t|
      t.integer :udprn, null: false
      t.integer :event, null: false
      t.integer :enquiry_count, null: false, default: 0
    end
  end
end
