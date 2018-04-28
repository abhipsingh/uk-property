class CacheSitemapEntity
  
  def self.cache_post_town
    counties = MatrixViewCount::COUNTY_MAP.values.uniq
    page_size = 50
    page = 0
    post_towns = []
    counter = 1
    MatrixViewCount::COUNTY_MAP.each do |post_town, county|
      pt = post_town.titleize
      ct = county.titleize
      hash = { post_town: pt, county: ct }
      pt_hash_val = MatrixViewService.form_hash(hash, :post_town)
      pt_hash = { name: pt, hash_str: pt_hash_val }
      post_towns.push(pt_hash)
      counter += 1
      if post_towns.length == page_size
        page = counter / page_size
        cache_key = "sitemap_post_town_cache_#{page}"
        ardb_client = Rails.configuration.ardb_client
        ardb_client.set(cache_key, post_towns.to_json)
        post_towns = []
      end
    end
    page = counter / page_size
    cache_key = "sitemap_post_town_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, post_towns.to_json)
    page
  end

  def self.cache_county
    counties = MatrixViewCount::COUNTY_MAP.values.uniq
    counter = 1
    county_arr = []
    page_size = 50
    counties.each do |county|
      ct = county.titleize
      hash = { county: ct }
      ct_hash_val = MatrixViewService.form_hash(hash, :county)
      ct_hash = { name: county, hash_str: ct_hash_val }
      county_arr.push(ct_hash)
      counter += 1
      if county_arr.length == page_size
        page = counter / page_size
        cache_key = "sitemap_county_cache_#{page}"
        ardb_client = Rails.configuration.ardb_client
        ardb_client.set(cache_key, county_arr.to_json)
        county_arr = []
      end
    end
    page = counter / page_size
    cache_key = "sitemap_county_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, county_arr.to_json)
    page
  end

  def self.cache_street
    sql = "select string_agg(distinct(concat(CASE WHEN td is not null THEN td ELSE dtd END, '-', dl, '-', district, '-', CASE WHEN td is not null THEN 't' ELSE 'f' END)), '|'), pt from property_addresses where td is not null or dtd is not null group by pt"
    result = PropertyAddress.connection.execute(sql)

    street_arr = []
    counter = 1
    page_size = 50
    result.each do |each_res|
      pt = each_res['pt']
      streets = each_res['string_agg']
      streets.split('|').each do |each_street|
        parts = each_street.split('-')
        dl = parts[1]
        td = parts[0]
        district = parts[2]
        pt_index = pt.to_i - 1
        pt_index = pt_index + 1 if pt_index < 76

        post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
        county = MatrixViewCount::COUNTY_MAP[post_town]
        
        hash = {  county: county, post_town: post_town, district: district }
        hash[:dependent_locality] = dl if !dl.blank?
        parts[3] == 't' ? hash[:thoroughfare_description] = td : hash[:dependent_thoroughfare_description] = td
        hash_type = nil
        parts[3] == 't' ? hash_type = :thoroughfare_description : hash_type = :dependent_thoroughfare_description

        hash_val = MatrixViewService.form_hash(hash, hash_type)
        val = { name: td, hash_str: hash_val }
        street_arr.push(val)
        if street_arr.length == page_size
          page = counter / page_size
          cache_key = "sitemap_streets_cache_#{page}"
          ardb_client = Rails.configuration.ardb_client
          ardb_client.set(cache_key, street_arr.to_json)
          street_arr = []
        end
        counter += 1
      end
    end

    page = counter / page_size
    cache_key = "sitemap_streets_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, street_arr.to_json)
    street_arr = []
    page
  end

  def self.cache_locality
    sql = "select string_agg(distinct(concat(dl, '-', district)), '|'), pt from property_addresses where dl is not null group by pt"
    result = PropertyAddress.connection.execute(sql)

    locality_arr = []
    counter = 1
    page_size = 50
    result.each do |each_res|
      pt = each_res['pt']
      localities = each_res['string_agg']
      localities.split('|').each do |locality|
        parts = locality.split('-')
        dl = parts[0]
        district = parts[1]
        pt_index = pt.to_i - 1
        pt_index = pt_index + 1 if pt_index < 76

        post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
        county = MatrixViewCount::COUNTY_MAP[post_town]
        
        hash = { county: county, post_town: post_town,  district: district, dependent_locality: dl }

        hash_val = MatrixViewService.form_hash(hash, :dependent_locality)
        val = { name: dl, hash_str: hash_val }
        locality_arr.push(val)
        if locality_arr.length == page_size
          page = counter / page_size
          cache_key = "sitemap_localities_cache_#{page}"
          ardb_client = Rails.configuration.ardb_client
          ardb_client.set(cache_key, locality_arr.to_json)
          locality_arr = []
        end
        counter += 1
      end
    end

    page = counter / page_size
    cache_key = "sitemap_localities_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, locality_arr.to_json)
    district_arr = []
    page
  end

  def self.cache_districts
    sql = "select string_agg(distinct(district), '|'),  pt from property_addresses group by pt"
    result = PropertyAddress.connection.execute(sql)

    district_arr = []
    counter = 1
    page_size = 50
    result.each do |each_res|
      pt = each_res['pt']
      districts = each_res['string_agg']
      districts.split('|').each do |district|
        pt_index = pt.to_i - 1
        pt_index = pt_index + 1 if pt_index < 76

        post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
        county = MatrixViewCount::COUNTY_MAP[post_town]
        
        hash = { county: county, post_town: post_town,  district: district }

        hash_val = MatrixViewService.form_hash(hash, :district)
        val = { name: district, hash_str: hash_val }
        district_arr.push(val)
        if district_arr.length == page_size
          page = counter / page_size
          cache_key = "sitemap_districts_cache_#{page}"
          ardb_client = Rails.configuration.ardb_client
          ardb_client.set(cache_key, district_arr.to_json)
          district_arr = []
        end
        counter += 1
      end
    end

    page = counter / page_size
    cache_key = "sitemap_districts_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, district_arr.to_json)
    district_arr = []
    page
  end

  def self.cache_sectors
    sql = "select string_agg(distinct(CONCAT(sector, '-', district)),'|'),  pt from property_addresses group by pt"
    result = PropertyAddress.connection.execute(sql)

    sector_arr = []
    counter = 1
    page_size = 50
    result.each do |each_res|
      pt = each_res['pt']
      sectors = each_res['string_agg']
      sectors.split('|').each do |sector|
        parts = sector.split('-')
        sector = parts[0]
        district = parts[1]
        pt_index = pt.to_i - 1
        pt_index = pt_index + 1 if pt_index < 76

        post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
        county = MatrixViewCount::COUNTY_MAP[post_town]
        
        hash = { county: county, post_town: post_town,  district: district, sector: sector }

        hash_val = MatrixViewService.form_hash(hash, :sector)
        val = { name: sector, hash_str: hash_val }
        sector_arr.push(val)
        if sector_arr.length == page_size
          page = counter / page_size
          cache_key = "sitemap_sectors_cache_#{page}"
          ardb_client = Rails.configuration.ardb_client
          ardb_client.set(cache_key, sector_arr.to_json)
          sector_arr = []
        end
        counter += 1
      end
    end

    page = counter / page_size
    cache_key = "sitemap_sectors_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, sector_arr.to_json)
    sector_arr = []
    page
  end

  def self.cache_units
    sql = "select string_agg(distinct(CONCAT(unit, '-', sector, '-', district)),'|'),  pt from property_addresses group by pt"
    result = PropertyAddress.connection.execute(sql)

    unit_arr = []
    counter = 1
    page_size = 50
    result.each do |each_res|
      pt = each_res['pt']
      units = each_res['string_agg']
      units.split('|').each do |unit|
        parts = unit.split('-')
        unit = parts[0]
        district = parts[2]
        sector = parts[1]
        pt_index = pt.to_i - 1
        pt_index = pt_index + 1 if pt_index < 76

        post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
        county = MatrixViewCount::COUNTY_MAP[post_town]
        
        hash = { county: county, post_town: post_town,  district: district, sector: sector, unit: unit }

        hash_val = MatrixViewService.form_hash(hash, :unit)
        val = { name: sector, hash_str: hash_val }
        sector_arr.push(val)
        if sector_arr.length == page_size
          page = counter / page_size
          cache_key = "sitemap_sectors_cache_#{page}"
          ardb_client = Rails.configuration.ardb_client
          ardb_client.set(cache_key, locality_arr.to_json)
          sector_arr = []
        end
        counter += 1
      end
    end

    page = counter / page_size
    cache_key = "sitemap_sectors_cache_#{page}"
    ardb_client = Rails.configuration.ardb_client
    ardb_client.set(cache_key, sector_arr.to_json)
    sector_arr = []
    page
  end

end

