class CreateSesEmailRequests < ActiveRecord::Migration

  def change
    create_table :ses_email_requests do |t|
      t.string :email
      t.string :klass
      t.jsonb :template_data
      t.string :template_name
      t.timestamp :created_at
    end
  end

end

