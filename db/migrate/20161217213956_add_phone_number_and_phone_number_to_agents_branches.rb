class AddPhoneNumberAndPhoneNumberToAgentsBranches < ActiveRecord::Migration
  def change
    add_column(:agents_branches, :email, :string)
    add_column(:agents_branches, :phone_number, :string)
    add_column(:agents_branches, :website, :string)


    add_column(:agents, :email, :string)
    add_column(:agents, :phone_number, :string)
    add_column(:agents, :website, :string)
    add_column(:agents, :address, :string)
    add_column(:agents, :image_url, :string)

    add_column(:agents_branches_assigned_agents, :title, :string)
    add_column(:agents_branches_assigned_agents, :office_phone_number, :string)
    add_column(:agents_branches_assigned_agents, :mobile_phone_number, :string)
  end
end
