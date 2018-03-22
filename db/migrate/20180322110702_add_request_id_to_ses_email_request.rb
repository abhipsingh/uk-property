class AddRequestIdToSesEmailRequest < ActiveRecord::Migration
  def change
    add_column(:ses_email_requests, :request_id, :string)
  end
end
