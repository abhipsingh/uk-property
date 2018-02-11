class TempUser < ActiveRecord::Base

  def self.from_omniauth(auth)
    new_params = auth.as_json.with_indifferent_access
    where(email: new_params['email']).first_or_initialize.tap do |user|
      user.details['provider'] = new_params['provider']
      user.details['uid'] = new_params['uid']
      user.details['first_name'] = new_params['first_name']
      user.details['last_name'] = new_params['last_name']
      user.details['email'] = new_params['email']
      user.details['image_url'] = new_params['image_url']
      user.auth_provider_auth_token = new_params['token']
      user.save!
    end
  end

end

