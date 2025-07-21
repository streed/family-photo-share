class SessionsController < Devise::SessionsController
  before_action :check_rate_limit, only: [:create]
  
  # Maximum number of failed attempts before lockout
  MAX_ATTEMPTS = 5
  # Lockout duration in minutes
  LOCKOUT_DURATION = 15

  def create
    self.resource = warden.authenticate!(auth_options)
    
    if resource
      # Clear failed attempts on successful login
      clear_failed_attempts
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
  rescue Devise::Strategies::Authenticatable::AuthenticationError
    # Increment failed attempts
    increment_failed_attempts
    super
  end

  private

  def check_rate_limit
    return unless rate_limit_exceeded?
    
    remaining_time = lockout_remaining_time
    flash[:alert] = "Too many failed login attempts. Please try again in #{remaining_time} minutes."
    redirect_to new_user_session_path
  end

  def rate_limit_exceeded?
    failed_attempts >= MAX_ATTEMPTS && within_lockout_period?
  end

  def failed_attempts
    session[:failed_login_attempts] || 0
  end

  def last_failed_attempt_time
    session[:last_failed_attempt] ? Time.parse(session[:last_failed_attempt]) : nil
  end

  def within_lockout_period?
    return false unless last_failed_attempt_time
    Time.current < last_failed_attempt_time + LOCKOUT_DURATION.minutes
  end

  def lockout_remaining_time
    return 0 unless last_failed_attempt_time && within_lockout_period?
    remaining_seconds = (last_failed_attempt_time + LOCKOUT_DURATION.minutes - Time.current).to_i
    (remaining_seconds / 60.0).ceil
  end

  def increment_failed_attempts
    session[:failed_login_attempts] = failed_attempts + 1
    session[:last_failed_attempt] = Time.current.to_s
  end

  def clear_failed_attempts
    session.delete(:failed_login_attempts)
    session.delete(:last_failed_attempt)
  end

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#failure" }
  end

  def failure
    increment_failed_attempts
    super
  end

  protected

  def rate_limit_info
    {
      failed_attempts: failed_attempts,
      remaining_attempts: [MAX_ATTEMPTS - failed_attempts, 0].max,
      locked_out: rate_limit_exceeded?,
      lockout_remaining_minutes: lockout_remaining_time
    }
  end
  helper_method :rate_limit_info
end