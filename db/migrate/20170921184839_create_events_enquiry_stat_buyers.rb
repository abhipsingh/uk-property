class CreateEventsEnquiryStatBuyers < ActiveRecord::Migration
  def change
    create_table :events_enquiry_stat_buyers do |t|
      t.integer :buyer_id, null: false
      t.integer :event, null: false
      t.integer :enquiry_count, default: 0, null: false
    end
  end
end
