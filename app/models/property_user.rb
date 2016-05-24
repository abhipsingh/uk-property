class PropertyUser < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable, :omniauthable,
         :omniauth_providers => [:facebook, :google_oauth2, :twitter]

  validates :email, uniqueness: true, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i  }

  def confirmation_required?
    super && email.present?
  end

  def password_required?
    super && provider.blank?
  end

  def self.from_omniauth(auth)
    provider, uid, email, full_name, first_name, last_name, profile_type, image= nil
    if auth.is_a?(Hash)
      provider = auth['provider']
      uid = auth['uid']
      email = auth['email']
      full_name = auth['first_name'] + '|' + auth['last_name']
      first_name = auth['first_name']
      last_name = auth['last_name']
      profile_type = auth['profile_type']
      image = "aaa"
    else
      provider = auth.provider
      uid = auth.uid
      email = auth.info.email if auth.info.email
      full_name = auth.info.name
      image = auth.info.image
    end
    user = PropertyUser.find_by_provider_and_uid(provider, uid)
    if user.blank?
      user = PropertyUser.new
      user.email = email
      user.full_name = full_name
      user.image = image
      user.provider = provider
      user.uid = uid
      user.first_name = first_name
      user.last_name = last_name
      user.profile_type = profile_type
      user.password = Devise.friendly_token[0,20]
      # user.skip_confirmation!
    end

    user
  end

  def self.image(user_data, provider)
    if provider == 'facebook'
      # user_data['info']['picture']
    else
      # user_data['info']['image']
    end
  end

  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  def profile_photo
    if provider == 'facebook'
      image + '?type=normal'
    else
      image
    end
  end
end
