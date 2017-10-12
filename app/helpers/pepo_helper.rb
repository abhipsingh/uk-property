module PepoHelper

  def self.api_call(api, query_hash)
    url = api
    api_key = ENV['PEPO_API_KEY']
    api_secret = ENV['PEPO_API_SECRET']
    request_time = DateTime.now.rfc3339
    delimiter = '::'
    signature = generate_signature(api_secret, "#{url}#{delimiter}#{request_time}")
    qry_params = {'request-time' => request_time, 'signature' => signature, 'api-key' => api_key}
    extra_qry_params = query_hash
 
    # Post Request
    uri = URI("https://pepocampaigns.com#{url}")
    http = Net::HTTP.new(uri.host, uri.port)
 
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    p qry_params.merge(extra_qry_params).to_query
    p uri.path
    #res = http.post(uri.path, qry_params.merge(extra_qry_params).to_query)
    body = JSON.parse(res.body)
    puts "API RESPONSE:: #{body}"
  end
 
  def self.generate_signature(api_secret, string_to_sign)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, api_secret, string_to_sign)
  end
 
end
