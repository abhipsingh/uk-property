# This migration was auto-generated via `rake db:generate_trigger_migration'.
# While you can edit this file, any changes you make to the definitions here
# will be undone by the next auto-generated trigger migration.

class CreateTriggersMultipleTables < ActiveRecord::Migration
  def up
    create_trigger("agents_branches_assigned_agents_before_update_of_email_row_tr", :generated => true, :compatibility => 1).
        on("agents_branches_assigned_agents").
        before(:update).
        of(:email) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end

    create_trigger("agents_branches_assigned_agents_before_insert_row_tr", :generated => true, :compatibility => 1).
        on("agents_branches_assigned_agents").
        before(:insert) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end

    create_trigger("property_buyers_before_update_of_email_row_tr", :generated => true, :compatibility => 1).
        on("property_buyers").
        before(:update).
        of(:email) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end

    create_trigger("property_buyers_before_insert_row_tr", :generated => true, :compatibility => 1).
        on("property_buyers").
        before(:insert) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end

    create_trigger("vendors_before_update_of_email_row_tr", :generated => true, :compatibility => 1).
        on("vendors").
        before(:update).
        of(:email) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end

    create_trigger("vendors_before_insert_row_tr", :generated => true, :compatibility => 1).
        on("vendors").
        before(:insert) do
      "NEW.email = LOWER(NEW.email); RETURN NEW;"
    end
  end

  def down
    drop_trigger("agents_branches_assigned_agents_before_update_of_email_row_tr", "agents_branches_assigned_agents", :generated => true)

    drop_trigger("agents_branches_assigned_agents_before_insert_row_tr", "agents_branches_assigned_agents", :generated => true)

    drop_trigger("property_buyers_before_update_of_email_row_tr", "property_buyers", :generated => true)

    drop_trigger("property_buyers_before_insert_row_tr", "property_buyers", :generated => true)

    drop_trigger("vendors_before_update_of_email_row_tr", "vendors", :generated => true)

    drop_trigger("vendors_before_insert_row_tr", "vendors", :generated => true)
  end
end
