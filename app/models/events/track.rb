class Events::Track < ActiveRecord::Base
  default_scope { where(active: true) }

  attr_accessor :details, :premium
  ADDRESS_ATTRS = [:property, :locality, :street]
  TRACKING_TYPE_MAP = {
    property_tracking: 1,
    locality_tracking: 2,
    street_tracking: 3,
  }

  BUYER_PROPERTY_PREMIUM_LIMIT = {
    'true' => 20,
    'false' => 10
  }

  BUYER_STREET_PREMIUM_LIMIT = {
    'true' => 10,
    'false' => 5
  }

  BUYER_LOCALITY_PREMIUM_LIMIT = {
    'true' => 5,
    'false' => 2
  }

  REVERSE_TRACKING_TYPE_MAP = TRACKING_TYPE_MAP.invert
  validate :locality_count_constraint
  validate :street_count_constraint
  validate :property_count_tracking

  def locality_count_constraint
    if REVERSE_TRACKING_TYPE_MAP[self.type_of_tracking] == :locality_tracking
      cond = Events::Track.where(buyer_id: self.buyer_id).where(type_of_tracking: TRACKING_TYPE_MAP[:locality_tracking]).count >= BUYER_LOCALITY_PREMIUM_LIMIT[premium.to_s]
      errors.add(:buyer_id, 'Exceeds number of localities allowed') if cond
    end
  end

  def street_count_constraint
    if REVERSE_TRACKING_TYPE_MAP[self.type_of_tracking] == :street_tracking
      cond = Events::Track.where(buyer_id: self.buyer_id).where(type_of_tracking: TRACKING_TYPE_MAP[:street_tracking]).count >= BUYER_STREET_PREMIUM_LIMIT[premium.to_s]
      errors.add(:buyer_id, 'Exceeds number of streets allowed') if cond
    end
  end

  def property_count_tracking
    if REVERSE_TRACKING_TYPE_MAP[self.type_of_tracking] == :property_tracking
      cond = Events::Track.where(buyer_id: self.buyer_id).where(type_of_tracking: TRACKING_TYPE_MAP[:property_tracking]).count >= BUYER_PROPERTY_PREMIUM_LIMIT[premium.to_s]
      errors.add(:buyer_id, 'Exceeds number of streets allowed') if cond
      errors.add(:buyer_id, 'Exceeds number of properties allowed') if cond
    end
  end

  def full_details
    return @details if @details
    @details = PropertyDetails.details(udprn)['_source']
  end

  def self.locality_hash(details)
    MatrixViewService.form_hash(details, :dependent_locality)
  end

  def self.td_hash(details)
    MatrixViewService.form_hash(details, :thoroughfare_description)
  end

  def self.dtd_hash(details)
    MatrixViewService.form_hash(details, :dependent_thoroughfare_description)
  end

  def self.street_hash(details)
    if details[:thoroughfare_description]
      td_hash(details)
    elsif details[:dependent_thoroughfare_description]
      dtd_hash(details)
    else
      nil
    end
  end

  def self.property_hash(details)
   "@_@_@_@_@_@_@_@_#{details[:udprn]}"
  end
end

