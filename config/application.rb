require File.expand_path('../boot', __FILE__)

require 'action_controller/railtie'
require 'active_model/railtie'
require 'active_record/railtie'
require 'rails/test_unit/railtie'

require 'rack/cors'
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)
require 'rails/all'

module TestApp
  ### Application level configs
  class Application < Rails::Application
    config.autoload_paths << Rails.root.join('lib')
    config.generators do |g|
      g.test_framework :mini_test, spec: true, fixture: false
    end
    config.middleware.insert_after 0, "Rack::Cors" do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :put, :delete, :options]
      end
    end
    # config.load_paths << "#{Rails.root}/app/services"
    config.active_record.logger = nil
    config.assets.initialize_on_precompile = false
    config.assets.paths << "#{Rails.root}/vendor/assets/fonts"
    config.active_record.raise_in_transactional_callbacks = true
    
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              'smtp.gmail.com',
      port:                 587,
      domain:               'prophety.com',
      user_name:            'test@prophety.co.uk',
      password:             'liverpool2017',
      authentication:       'plain',
      enable_starttls_auto: true  
    }


    config.action_mailer.preview_path = '/app/mailers/previews'
    
  end
  
end
