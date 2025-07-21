require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module FamilyPhotoShare
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Set timezone to UTC
    config.time_zone = "UTC"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure Active Storage for local storage in development
    config.active_storage.variant_processor = :mini_magick

    # Allow additional parameters for Devise
    config.to_prepare do
      Devise::RegistrationsController.class_eval do
        before_action :configure_permitted_parameters

        private

        def configure_permitted_parameters
          devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name, :phone_number, :provider, :uid])
          devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name, :display_name, :bio, :phone_number])
        end
      end
    end
  end
end
