class Vendor < ActiveRecord::Base
  has_secure_password
  STATUS_HASH = {
    'Verified' => 1,
    'Unverified' => 2
  }

  REVERSE_STATUS_HASH = STATUS_HASH.invert
end
