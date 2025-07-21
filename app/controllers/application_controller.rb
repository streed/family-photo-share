class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # Devise authentication
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  protected

  def handle_record_not_found
    redirect_to root_path, alert: 'The requested resource was not found.'
  end

  def handle_parameter_missing
    redirect_to root_path, alert: 'Required information was missing from your request.'
  end

  def handle_access_denied
    redirect_to root_path, alert: 'You do not have permission to access this resource.'
  end

  def handle_validation_errors(record)
    if record.errors.any?
      flash.now[:alert] = "Please correct the following errors: #{record.errors.full_messages.to_sentence}"
    end
  end
end
