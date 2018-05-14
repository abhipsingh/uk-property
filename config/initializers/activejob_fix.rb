class ActiveSupport::TimeWithZone
  include GlobalID::Identification

  def id
    (Time.zone.now.to_f * 1000).round
  end

  def self.find(milliseconds_since_epoch)
    Time.zone.at(milliseconds_since_epoch.to_f / 1000)
  end
end

class Time
  include GlobalID::Identification

  def id
    (Time.zone.now.to_f * 1000).round
  end

  def self.find(milliseconds_since_epoch)
    Time.zone.at(milliseconds_since_epoch.to_f / 1000)
  end
end


class Date
  include GlobalID::Identification

  alias_method :id, :to_s
  def self.find(date_string)
    Date.parse(date_string)
  end
end

