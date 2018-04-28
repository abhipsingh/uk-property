class SitemapController < ActionController::Base
  
  def streets
    cache_key = "sitemap_streets_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def localities
    cache_key = "sitemap_localities_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def post_towns
    cache_key = "sitemap_post_town_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def counties
    cache_key = "sitemap_county_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def districts
    cache_key = "sitemap_districts_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def sectors
    cache_key = "sitemap_sectors_cache_#{params[:page].to_i}"
    ardb_client = Rails.configuration.ardb_client 
    val = Oj.load(ardb_client.get(cache_key))
    render json: val, status: 200
  end

  def units
    page = params[:page].to_i - 1
    page_size = 10
    sql = "select distinct(test_postcode), dl, td, dtd, pt from property_addresses limit #{page_size} offset #{page_size*page}"
    results = PropertyAddress.connection.execute(sql)
    response = []
    results.each do |each_postcode|
      postcode = each_postcode['test_postcode']
      z_rindex = postcode.rindex('Z')
      sector_suffix = nil
      if z_rindex.to_i > 2
        sector_suffix = postcode[z_rindex+1]
        postcode[z_rindex] = ' '
      else
        sector_suffix = postcode[4]
        postcode = postcode[0..3] + ' ' + postcode[4..6]
      end

      sector = postcode.split(' ')[0] + ' ' + sector_suffix
      pt = each_postcode['pt'].to_i

      pt_index = pt.to_i - 1
      pt_index = pt_index + 1 if pt_index < 76
      post_town = MatrixViewCount::POST_TOWNS[pt_index].titleize
      county = MatrixViewCount::COUNTY_MAP[post_town]
      hash = { post_town: post_town, county: county, district: postcode.split(' ')[0], sector: sector, unit: postcode }
      hash[:dependent_locality]  = each_postcode['dl'] if each_postcode['dl']
      hash[:thoroughfare_description]  = each_postcode['td'] if each_postcode['td']
      hash[:dependent_thoroughfare_description]  = each_postcode['dtd'] if each_postcode['dtd']
      hash_val = MatrixViewService.form_hash(hash, :unit)
      val = { name: postcode, hash_str: hash_val }
      response.push(val)
    end

    render json: response, status: 200
  end

end

