class Vendor < ActiveRecord::Base
  STATUS_HASH = {
    'Verified' => 1,
    'Unverified' => 2
  }

  REVERSE_STATUS_HASH = STATUS_HASH.invert
end
