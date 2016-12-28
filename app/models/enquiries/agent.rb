module Enquiries
  class Agent

  end
end


#### A table with date, property_id and maybe buyer_id as the primary key
#### Query by date. Responses are further inserts 
#### Clustering key is events. Events also include response by the agents.


#### For No of views and enquiries of buyers. Buyer_events_views and buyers_events_enquiries
#### will be a seperate table where property_id will 
#### be a clustering column

PALINDROME_MAP = {}

def longest_palindrome(str, start, ending)
  if is_palindrome(str, start, ending)
    return str[start..ending]
  else
    str1 = longest_palindrome(str, start+1, ending)
    str2 = longest_palindrome(str, start, ending-1)
    str = nil
    str1.length > str2.length ? str = str1 : str = str2
    str
  end




end


def is_palindrome(str, start, ending)
  if PALINDROME_MAP["#{start}_#{ending}"].nil?
    val = str[start] == str[ending] && is_palindrome(str, start+1, ending-1)
    PALINDROME_MAP["#{start}_#{ending}"] = val
    return val
  else
    return PALINDROME_MAP["#{start}_#{ending}"]
  end
end


def derangements(length)
end
