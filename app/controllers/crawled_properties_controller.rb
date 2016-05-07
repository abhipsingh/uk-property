### Base controller
class CrawledPropertiesController < ActionController::Base

  def search
  end

  def search_results
    search_str = params[:str]
    search_sql = Agents::Branches::CrawledProperty.where("ARRAY[?]::varchar[] && tags", [search_str]).select(:id).limit(100).to_sql
    results = Agent.connection.execute(search_sql)
    crawled_property_urls = []
    crawled_property_url_prefix = '/crawled_properties/'
    results.each do |each_res|
      crawled_property_urls.push(crawled_property_url_prefix + each_res['id'] + '/show')
    end
    render json: crawled_property_urls, status: 200
  end

  def show
    @stored_response = Agents::Branches::CrawledProperty.where(id: params[:id].to_i).first.stored_response rescue nil
    @iframe_url = PropertyDetails.get_iframe_url_for_address(@stored_response['address'])
    @images = Agents::Branches::CrawledProperty.images_from_aws(@stored_response) if @stored_response
  end

end
