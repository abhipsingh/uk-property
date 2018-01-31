class Vendor < ActiveRecord::Base
  has_secure_password
  STATUS_HASH = {
    'Verified' => 1,
    'Unverified' => 2
  }
  belongs_to :buyer, class_name: 'PropertyBuyer'
  has_many :leads, class_name: '::Agents::Branches::AssignedAgents::Lead'

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  INVITED_FROM_CONST = {
    crawled: 1,
    family: 2
  }
  
  PROPERTY_CLAIM_LIMIT_MAP = {
    'true' => 5,
    'false' => 2
  }

  QUOTE_LIMIT_MAP = {
    'true' => 4,
    'false' => 3
  }
  PROPERTY_CLAIM_LIMIT = 10

   def self.from_omniauth(auth)
     new_params = auth.as_json.with_indifferent_access
     where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
       user.provider = new_params['provider']
       user.uid = new_params['uid']
       user.first_name = new_params['first_name']
       user.last_name = new_params['last_name']
       user.name = new_params['first_name'] + ' ' + new_params['last_name']
       user.email = new_params['email']
       user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
       user.oauth_token = new_params['token']
       #user.oauth_expires_at = Time.at(new_params['expires_at']) rescue 1.hours.from_now
       user.password = "#{ENV['OAUTH_PASSWORD']}"
       user.save!
     end
  end
  
  def as_json(options = {})
    super(:except => [:password, :password_digest])
  end

  def self.fetch_details(attrs=[], ids=[])
    where(id: ids).select(attrs)
  end

end
