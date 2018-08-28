class AddBuyerUniqCalendarEvent < ActiveRecord::Migration
  def up
    execute("CREATE EXTENSION btree_gist;")
    execute("ALTER TABLE agent_calendar_unavailabilities
  add constraint uniq_calendar_buyer_idx
  EXCLUDE USING gist (
            buyer_id WITH =,
            tsrange(start_time, end_time) WITH &&)")

    execute("ALTER TABLE agent_calendar_unavailabilities
  add constraint uniq_calendar_agent_idx
  EXCLUDE USING gist (
            agent_id WITH =,
            tsrange(start_time, end_time) WITH &&)")

  end

  def down
    execute("drop constraint uniq_calendar_buyer_idx");
    execute("drop constraint uniq_calendar_agent_idx");
  end
end

