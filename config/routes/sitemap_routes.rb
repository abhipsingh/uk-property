Rails.application.routes.draw do
  get '/sitemap/counties',     to: 'sitemap#counties'
  get '/sitemap/post_towns',   to: 'sitemap#post_towns'
  get '/sitemap/localities',   to: 'sitemap#localities'
  get '/sitemap/streets',      to: 'sitemap#streets'
  get '/sitemap/districts',    to: 'sitemap#districts'
  get '/sitemap/sectors',      to: 'sitemap#sectors'
  get '/sitemap/units',        to: 'sitemap#units'
end
