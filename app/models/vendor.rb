class Vendor < ActiveRecord::Base
  has_secure_password
  STATUS_HASH = {
    'Verified' => 1,
    'Unverified' => 2
  }
  belongs_to :buyer, class_name: 'PropertyBuyer'
  has_many :leads, class_name: '::Agents::Branches::AssignedAgents::Lead'

  REVERSE_STATUS_HASH = STATUS_HASH.invert
  # def self.from_omniauth(auth)
  #   new_params = auth.as_json.with_indifferent_access
  #   Rails.logger.info(new_params)
  #   where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
  #     user.provider = new_params['provider']
  #     user.uid = new_params['uid']
  #     user.name = new_params['info']['name']
  #     user.email = new_params['info']['email']
  #     user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
  #     user.oauth_token = new_params['credentials']['token']
  #     user.oauth_expires_at = Time.at(new_params['credentials']['expires_at'])
  #     user.password = "12345678"
  #     user.save!
  #   end
  # end

  def as_json(options = {})
    super(:except => [:password, :password_digest])
  end

end
