class AddAttributesToDeveloper < ActiveRecord::Migration
  def change
    add_column(:developers_branches_employees, :first_name, :string)
    add_column(:developers_branches_employees, :last_name, :string)
    add_column(:developers_branches_employees, :password, :string)
    add_column(:developers_branches_employees, :password_digest, :string)
    add_column(:developers_branches_employees, :provider, :string)
    add_column(:developers_branches_employees, :uid, :string)
    add_column(:developers_branches_employees, :oauth_token, :string)
    add_column(:developers_branches_employees, :oauth_expires_at, :string)
  end
end

