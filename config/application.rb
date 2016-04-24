require File.expand_path('../boot', __FILE__)

require 'action_controller/railtie'
require 'active_model/railtie'
require 'active_record/railtie'
require 'rails/test_unit/railtie'

require 'rack/cors'
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TestApp
  ### Application level configs
  class Application < Rails::Application
    config.autoload_paths << Rails.root.join('lib')
    config.generators do |g|
      g.test_framework :mini_test, spec: true, fixture: false
    end
    config.to_prepare do
        Devise::SessionsController.layout 'login'
        Devise::RegistrationsController.layout 'login'
        Devise::PasswordsController.layout 'login'
        Devise::ConfirmationsController.layout 'login'
      end
    config.middleware.insert_after 0, "Rack::Cors" do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :put, :delete, :options]
      end
    end
    config.active_record.logger = nil
    config.assets.initialize_on_precompile = false
    config.assets.paths << "#{Rails.root}/vendor/assets/fonts"
    
  end
  
end
