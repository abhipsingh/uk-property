class PropertyBuyer < ActiveRecord::Base

  attr_accessor :renter_address, :verification_hash, :email_udprn, :vendor_email,
                :social_sign_status
  has_secure_password
  has_one :rent_requirement, class_name: 'RentRequirement', foreign_key: :buyer_id
  PREMIUM_COST = 25

  trigger.before(:update).of(:email) do
    "NEW.email = LOWER(NEW.email); RETURN NEW;"
  end

  trigger.before(:insert) do
    "NEW.email = LOWER(NEW.email); RETURN NEW;"
  end


  STATUS_HASH = {
    green: 1,
    amber: 2,
    red: 3
  }

  belongs_to :vendor, class_name: 'Vendor'

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  BUYING_STATUS_HASH = {
    'First time buyer' => 1,
    'Not a first time buyer' => 2,
    'Property Investor' => 3,
    'I am currently renting a property' => 4,
    'I live with friends and family' => 5
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
    "Can't sell current property" => 2,
    "Can't sell right property" => 3
  }

  PREMIUM_AMOUNT = 2

  BUYER_ENQUIRY_LIMIT = {
    'true' => 15,
    'false' => 10
  }

  BUYER_TRACKING_LIMIT = {
    'locality_tracking' => {
      'true' => 2,
      'false' => 1
    },
    'street_tracking' => {
      'true' => 5,
      'false' => 2
    },
    'property_tracking' => {
      'true' => 10,
      'false' => 5
    }
  }

  REVERSE_BIGGEST_PROBLEM_HASH = BIGGEST_PROBLEM_HASH.invert
  def self.from_omniauth(auth)
    new_params = auth.as_json.with_indifferent_access
    where(new_params.slice(:provider, :uid)).first_or_initialize.tap do |user|
      user.new_record? ? user.social_sign_status = true : user.social_sign_status = false
      Rails.logger.info("FB_LOGIN_#{user.social_sign_status}")
      user.provider = new_params['provider']
      user.uid = new_params['uid']
      user.first_name = new_params['first_name']
      user.last_name = new_params['last_name']
      user.name = new_params['first_name'] + ' ' + new_params['last_name']
      user.email_id = new_params['email']
      if new_params['provider'] == 'linkedin'
        user.image_url = new_params['image_url']
      else
        user.image_url = "http://graph.facebook.com/#{new_params['uid']}/picture?type=large"
      end
      user.oauth_token = new_params['token']
      #user.oauth_expires_at = Time.at(new_params['expires_at'])
      user.password = "#{ENV['OAUTH_PASSWORD']}"
      user.email = user.email_id
      user.account_type = "a"
      user.save!
      #Rails.logger.info(user)
    end
  end

  ### PropertyBuyer.find(23).send_vendor_email("test@prophety.co.uk", 10968961)
  def send_vendor_email(vendor_email, udprn, is_renter=true)
    hash_obj = create_hash(vendor_email, udprn)
    self.verification_hash = hash_obj.hash_value
    self.vendor_email = vendor_email
    self.email_udprn = udprn
    details = PropertyDetails.details(udprn)['_source']
    self.renter_address = details['address']

    ### If the inviter is a renter, then send a different mail than
    ### when its a buyer
    if is_renter
      VendorMailer.welcome_email_from_a_renter(self).deliver_now
    else
      VendorMailer.welcome_email_from_a_friend(self).deliver_now
    end

    ### http://prophety-test.herokuapp.com/auth?verification_hash=<%=@user.verification_hash%>&udprn=<%=@user.email_udprn%>&email=<%=@user.vendor_email%>
  end

  def create_hash(vendor_email, udprn)
    salt_str = "#{vendor_email}_#{self.id}_#{self.class}"
    hash_value = BCrypt::Password.create salt_str
    hash_obj = VerificationHash.create!(email: vendor_email, hash_value: hash_value, entity_id: self.id, entity_type: 'Vendor', udprn: udprn.to_i)
    hash_obj
  end

  def self.filter_buyers(udprn)
    buyer_ids = []
    details = PropertyDetails.details(udprn)['_source']
    (Events::Track::ADDRESS_ATTRS-[:property]).each do |level|
      hash_str = Events::Track.send("#{level}_hash", details)
      if hash_str
        buyer_ids = buyer_ids + Events::Track.where(hash_str: hash_str).pluck(:id)
      end
    end

    hash_str = Events::Track.property_hash(details)
    property_tracking_buyer_ids = Events::Track.where(hash_str: hash_str).pluck(:id)

    price = details[:sale_price]
    price ||= details[:current_valuation]
    price ||= details[:last_sale_price]

    query = where(id: buyer_ids)
    query = query.where("budget_to > ? AND budget_from < ?", price, price) if price
    query = query.where("'#{details[:property_type]}' = ANY(property_types)", ) if details[:property_type]
    query = query.where("max_beds >= ? AND min_beds <= ? ", details[:beds].to_i, details[:beds].to_i) if details[:beds]
    query = query.where("max_baths >= ? AND min_baths <= ? ", details[:baths].to_i, details[:baths].to_i) if details[:baths]
    query = query.where("max_receptions >= ? AND min_receptions <= ? ", details[:receptions].to_i, details[:receptions].to_i) if details[:receptions]
    buyer_ids = query.pluck(:id)
    buyer_ids = buyer_ids + property_tracking_buyer_ids
    where(id: buyer_ids)
  end

  def self.suggest_buyers(search_str)
    where("to_tsvector('simple', ( name || ' '  || mobile))  @@ to_tsquery('simple', ?) OR email LIKE ? ", "#{search_str}:*", "#{search_str}%")
  end

  def as_json option = {}
    super(:except => [:password, :password_digest])
  end

  def send_email_for_a_matching_property(details, tracking_date, type_of_tracking, buyer_id, update_hash)
    first_name = self.first_name
    last_name = self.last_name
    email = self.email
    details[:address] = PropertyDetails.address(details)
    BuyerMailer.send_email_for_a_matching_property(first_name, last_name, email, details, tracking_date, type_of_tracking, buyer_id, update_hash).deliver_now
  end
end

