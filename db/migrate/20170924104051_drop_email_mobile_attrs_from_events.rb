class DropEmailMobileAttrsFromEvents < ActiveRecord::Migration
  def change
    remove_column(:events, :agent_email)
    remove_column(:events, :agent_mobile)
    remove_column(:events, :buyer_name)
    remove_column(:events, :buyer_mobile)
  end
end
