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

end
