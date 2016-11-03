class PropertyBuyer < ActiveRecord::Base
  STATUS_HASH = {
    green: 1,
    amber: 2,
    red: 3
  }

  REVERSE_STATUS_HASH = STATUS_HASH.invert

  BUYING_STATUS_HASH = {
    'First time buyer' => 1,
    'Buyer(not first time)' => 2,
    'Property to sell' => 3,
    'Property to rent' => 4,
    'I have an offer on my Property' => 5,
    'I have recently sold' => 6,
    'Property investor' => 7,
    'Just browsing' => 8,
    'Other' => 9
  }

  REVERSE_BUYING_STATUS_HASH = BUYING_STATUS_HASH.invert

  FUNDING_STATUS_HASH = {
    'Mortgage approved' => 1,
    'Cash buyer' => 2,
    'Funds pending' => 3,
    'N/A' => 4,
  }

  REVERSE_FUNDING_STATUS_HASH = FUNDING_STATUS_HASH.invert

  BIGGEST_PROBLEM_HASH = {
    'Funding' => 1,
    "Can't Sell" => 2,
    'N/A' => 3
  }

  REVERSE_BIGGEST_PROBLEM_HASH = BIGGEST_PROBLEM_HASH.invert

end
