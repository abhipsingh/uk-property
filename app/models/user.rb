class User

  def self.postcode_area_panel_details
    ## TODO - Move to cache response
    details = Rails.configuration.ardb_client.get("postcode_area_panel_details")
    return {postcode_area_panel_details: Oj.load(details)} if details.present?
    postcode_area_details = User.postcode_area_panel_details_cache
    {postcode_area_panel_details: postcode_area_details}
  end

  def self.postcode_area_panel_details_cache
    postcode_areas = ['AB', 'AL', 'B', 'BA', 'BB', 'BD', 'BH', 'BL', 'BN', 'BR', 'BS', 'BT', 'CA', 'CB', 'CF', 'CH', 'CM', 'CO', 'CR', 'CT', 'CV', 'CW', 'DA', 'DD', 'DE', 'DG', 'DH', 'DL', 'DN', 'DT', 'DY', 'E', 'EC', 'EH', 'EN', 'EX', 'FK', 'FY', 'G', 'GL', 'GU', 'HA', 'HD', 'HG', 'HP', 'HR', 'HS', 'HU', 'HX', 'IG', 'IP', 'IV', 'KA', 'KT', 'KW', 'KY', 'L', 'LA', 'LD', 'LE', 'LL', 'LN', 'LS', 'LU', 'M', 'ME', 'MK', 'ML', 'N', 'NE', 'NG', 'NN', 'NP', 'NR', 'NW', 'OL', 'OX', 'PA', 'PE', 'PH', 'PL', 'PO', 'PR', 'RG', 'RH', 'RM', 'S', 'SA', 'SE', 'SG', 'SK', 'SL', 'SM', 'SN', 'SO', 'SP', 'SR', 'SS', 'ST', 'SW', 'SY', 'TA', 'TD', 'TF', 'TN', 'TQ', 'TR', 'TS', 'TW', 'UB', 'W', 'WA', 'WC', 'WD', 'WF', 'WN', 'WR', 'WS', 'WV', 'YO']
    postcode_area_details = []
    postcode_areas.reverse.each do |postcode_area|
      area_details = {}
      area_details['postcode_area'] = postcode_area
      queries= {}
      queries['email_branches'] = "SELECT sum(jsonb_array_length(invited_agents)) as count FROM agents_branches WHERE district ~ '^" + postcode_area + "[0-9]+'"
      queries['registered_branches'] = "SELECT count(distinct(agents_branches.id)) FROM agents_branches JOIN agents_branches_assigned_agents ags ON agents_branches.id = ags.branch_id WHERE  district ~ '^" + postcode_area + "[0-9]+'"
      queries['registered_agents'] = "SELECT count(agents_branches_assigned_agents.id) FROM agents_branches JOIN agents_branches_assigned_agents ON agents_branches.id = agents_branches_assigned_agents.branch_id WHERE agents_branches.district ~ '^" + postcode_area + "[0-9]+'" 
      queries['draft_properties'] = "SELECT count(*) FROM agents_branches_crawled_properties WHERE district ~ '^" + postcode_area + "[0-9]+'"
      queries['verified_draft_properties'] = "SELECT count(*) FROM agents_branches_crawled_properties WHERE udprn is not null AND district ~ '^" + postcode_area + "[0-9]+'"
      queries['vendor_claimed_property'] = "SELECT count(*) from agents_branches_assigned_agents_leads where  agents_branches_assigned_agents_leads.owned_property = 'f' AND agents_branches_assigned_agents_leads.district ~ '^" +  postcode_area + "[0-9]+'"
      queries['manual_properties'] = "SELECT count(*) from agents_branches_assigned_agents_leads where  agents_branches_assigned_agents_leads.owned_property = 't' AND agents_branches_assigned_agents_leads.district ~ '^" +  postcode_area + "[0-9]+'"
      queries['total_listings'] = "SELECT  count(udprn) FROM property_addresses WHERE  (to_tsvector('simple'::regconfig, postcode)  @@ to_tsquery('simple', '" + postcode_area + ":*')) "
      queries.each do |key, query|
        area_details[key] = ActiveRecord::Base.connection.execute(query).as_json.first["count"].to_i 
      end
      matching_postcode_areas = postcode_areas.select{ |t| t.start_with?(postcode_area) } - [ postcode_area ]
      matching_postcode_listing_sum = postcode_area_details.select{ |t| matching_postcode_areas.include?(t['postcode_area']) }.map{ |t| t['total_listings'].to_i }.sum
      area_details['total_listings'] = area_details['total_listings'] - matching_postcode_listing_sum
      area_details['total_percentage_draft'] = area_details['draft_properties'].to_f / area_details['total_listings']
      api = ::PropertySearchApi.new(filtered_params: {})
      ["Green", "Amber", "Red"].each do |property_status_type|
        query = {query: {bool: {must: [{term: {area: postcode_area}}, {term: {property_status_type: property_status_type}}]}}}
        area_details[property_status_type.downcase] = Oj.load(api.post_url(query.as_json, Rails.configuration.address_index_name, Rails.configuration.address_type_name, '_search?search_type=count')[0])["hits"]["total"]
      end
      area_details["unknown"] = area_details["total_listings"] - area_details["green"] - area_details["amber"] - area_details["red"]
      postcode_area_details << area_details
    end
    Rails.configuration.ardb_client.set("postcode_area_panel_details", Oj.dump(postcode_area_details), {ex: 1.day})
    postcode_area_details
  end
end
