
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/override/search' -d '{"user_id" : 25, "saved_searches": [{"beds":true}]   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/search' -d '{"user_id" : 25, "new_saved_search": {"beds":true}   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/searches' -d '{"user_id" : 25}'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/shortlist' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/shortlist' -d '{"user_id" : 25, "shortlisted_udprns": [123456]   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/delete/shortlist' -d '{"user_id" : 25, "deleted_udprns": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/viewings' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/viewings' -d '{"user_id" : 25, "viewings": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/offers' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/offers' -d '{"user_id" : 25, "offers": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/callbacks' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/callbacks' -d '{"user_id" : 25, "callbacks": [123456]   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/messages' -d '{"user_id" : 25}'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/message' -d '{"user_id" : 25, "to": 123456, "content" : "Ta da da da"   }'
# curl -XPOST -H 'Content-Type:application/json' 'http://localhost:3000/buyers/new/matrix/search' -d '{"user_id" : 25, "new_matrix_search": "Merseyside"   }'
# curl -XGET -H 'Content-Type:application/json' 'http://localhost:3000/buyers/matrix/searches' -d '{"user_id" : 25}'


