class PropertyBuyer < ActiveRecord::Base
  STATUS_HASH = {
    green: 1,
    amber: 2,
    red: 3
  }

  REVERSE_STATUS_HASH = STATUS_HASH.invert
end
