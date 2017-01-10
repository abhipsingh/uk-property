class PropertyBuyer < ActiveRecord::Base
  has_secure_password
  STATUS_HASH = {
    green: 1,
    amber: 2,
    red: 3
  }

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  BUYING_STATUS_HASH = {
    'First time buyer' => 1,
    'Not a first time buyer' => 2,
    'Property investor' => 3,
    'Looking to rent' => 4
  }

  REVERSE_BUYING_STATUS_HASH = BUYING_STATUS_HASH.invert

  FUNDING_STATUS_HASH = {
    'Mortgage approved' => 1,
    'Cash buyer' => 2,
    'Not in place yet' => 3
  }

  REVERSE_FUNDING_STATUS_HASH = FUNDING_STATUS_HASH.invert

  BIGGEST_PROBLEM_HASH = {
    'Money' => 1,
    "Cannot Sell current property" => 2,
    "Cannot Sell right property" => 3
  }

  REVERSE_BIGGEST_PROBLEM_HASH = BIGGEST_PROBLEM_HASH.invert
  def self.from_omniauth(auth)
    new_params = auth.as_json.with_indifferent_access
    Rails.logger.info(new_params)
    where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
      user.provider = new_params['provider']
      user.uid = new_params['uid']
      user.name = new_params['info']['name']
      user.email_id = new_params['info']['email']
      user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
      user.oauth_token = new_params['credentials']['token']
      user.oauth_expires_at = Time.at(new_params['credentials']['expires_at'])
      user.password = "12345678"
      user.email = user.email_id
      user.account_type = "a"
      user.save!
    end
  end
end
