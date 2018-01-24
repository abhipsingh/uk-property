Rails.application.configure do
  # Settings specified here will take precedence
  # over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true
  Rails.logger = ActiveSupport::Logger.new(File.expand_path('/mnt3/rails_logs/production.log', __FILE__))
  # Rails.logger = ActiveSupport::Logger.new('log/production.log')
  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.action_mailer.default_url_options = { :host => 'localhost:3000' }

  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Enable Rack::Cache to put a simple HTTP cache in front of your application
  # Add `rack-cache` to your Gemfile before enabling this.
  # For large-scale production use, consider using a caching reverse proxy like
  # NGINX, varnish or squid.
  # config.action_dispatch.rack_cache = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :debug

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new
  config.middleware.use Rack::Attack

end

