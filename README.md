
# Below are the examples given to consume the APIs
* Query params will control the usage of APIs. 
* Query params ending with the string `_types` can have multiple values seperated with comma. (`Multiple value` filters) e.g. `property_types=Countryside,Cottage` specifies the filter for these particular values of `property_type` attribute
* Query params starting with `min_` or `max_` is used for computing the results between a numerical value.(`Range` filters) e.g. `min_beds=1&max_beds=2` specifies a filter of beds ranging from 1 to 2. Here the `key` is `beds`.
* Query params of the type other than the above is used for direct filter of attributes in which the `key` of query_params is the attribute itself on which filter has to be applied and the `value` is the value itself which is desired in the results after applying the filter. e.g. `listed_status=None`, `property_style=Period`. These types of filters are `direct` filters

Examples
======
* [Budget from](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?min_budget=4500) Minimum budget filter(`Range`)
* [Budget to](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?max_budget=4500) Maximum budget filter(`Range`)
* [Property Types](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?property_types=Cottage) Property Types filter(Multiple types can be passed seperated with comma. For all possible types, refer to the CSV doc(`Multiple value`)
* [Beds filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?min_beds=1&max_beds=1) This is a range filter. `min_beds` & `max_beds` are the query params(`Range`)
* For baths same as above just change the attribute name from `beds` to `baths`(`Range`)
* For receptions same as above change the attribute name from `baths` to `receptions`(`Range`)
* [Property Status Type filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?property_status_type=Green) This is a direct filter. Only one type can be applied(`Direct`)
* [Match Type filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?match_types=All) Multiple values can be provided, comma seperated. Refer to the CSV for the list of values(`Multiple value`)
* [Monitoring Type](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?monitoring_types=Yes) Same as above. Just change the key name from `match_types` to `monitoring_types`(`Multiple value`)
* [Parking Type](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?parking_types=Underground)Same as above. Just change the key name from `monitoring_types` to `parking_types`(`Multiple value`)
* [Outside space Type](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?outside_space_types=Terrace)Same as above. Just change the key name from `parking_types` to `outside_space_types`(`Multiple value`)
* [Additional feature types](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?additional_features_types=Ensuite%2Bbathroom)Same as above. Just change the key name from `outside_space_types` to `additional_features_types`(`Multiple value`)
* [Status filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?listed_status=None) Listed status is a direct filter. For the list of possible values, refer to the CSV. `key` is `listed_status` and `value` is `None` in this case.(`Multiple value`)
* [Chain free filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?chain_free=Yes) Chain free filter can only have two values `Yes` or `No`(`Direct`)
* [Price reduced filter](http://ec2-52-10-153-115.us-west-2.compute.amazonaws.com/api/v0/properties/search?price_reduced=Yes) Two values possible (`Direct`)
* Other direct filters are keys `tenure`, `epc`, `property_style`, `decorative_condition`, `central_heating`, `photos` and  `floorplan`. All the values possible for these keys has given in the CSV.
* Other range filters are 
   1) `external_property_size`
   2) `internal_property_size`
   3) `total_property_size` 
   4) `date_added`
   5) `timeframe`
   
   All the above filters are going to have query_params keys starting with `min_` or `max`. e.g. `min_total_property_size=6000`, `max_date_added=2016-03-01`.
   
   For `date_added`, `time_frame` filter values have to be in the format `YYYY-MM-DD`. e.g. `2016-03-01`

Pagination
=====

For pagination please add a url_param key `p` and value as the page you want to navigate to . e.g. `url?p=1`, `url?p=7`

Sorting
====

For sorting two keys are required `sort_key`(i.e. the attribute on which sorting has to be applied and `sort_order`( the order or sorting `asc`/`desc`

* e.g. `sort_key=budget&sort_order=asc` Min budget first
* e.g. `sort_key=date_added&sort_order=desc` Latest result first
* Sorting can only be applied on the attributes on which `Range` filters can be applied. e.g. `date_added`, `budget`, `external_property_size` etc.
* Attributes on which sorting is to be applied are
   1) `date_added`
   2) `price`
   3) `valuation`
   4) `dream_price`
   5) `price_changed`


