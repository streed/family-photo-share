class SessionsController < Devise::SessionsController
  # Maximum number of failed attempts before lockout
  MAX_ATTEMPTS = 5
  # Lockout duration in minutes
  LOCKOUT_DURATION = 15

  def create
    # Check if user is locked out before attempting authentication (skip in development)
    if !Rails.env.development? && rate_limit_exceeded?
      remaining_time = lockout_remaining_time
      flash.now[:alert] = "Too many failed login attempts. Please try again in #{remaining_time} #{'minute'.pluralize(remaining_time)}."
      self.resource = resource_class.new(sign_in_params)
      render :new and return
    end
    
    # Store email before attempting authentication
    attempted_email = params.dig(:user, :email)
    
    # Try authentication with Devise
    self.resource = warden.authenticate!(auth_options)
    
    if resource && resource.persisted?
      # Successful authentication
      clear_failed_attempts unless Rails.env.development?
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    end
    
  rescue Warden::NotAuthenticated
    # Authentication failed
    increment_failed_attempts unless Rails.env.development?
    
    # Set up resource for form redisplay
    self.resource = resource_class.new(email: attempted_email)
    
    # Add custom error message
    if Rails.env.development?
      flash.now[:alert] = "Invalid email or password. Please try again."
    else
      attempts_left = MAX_ATTEMPTS - failed_attempts
      if attempts_left == 1
        flash.now[:alert] = "Invalid email or password. Warning: You have 1 more attempt before your account is temporarily locked."
      elsif attempts_left > 0
        flash.now[:alert] = "Invalid email or password. You have #{attempts_left} attempts remaining."
      else
        remaining_time = lockout_remaining_time
        flash.now[:alert] = "Too many failed login attempts. Your account is temporarily locked. Please try again in #{remaining_time} #{'minute'.pluralize(remaining_time)} or reset your password."
      end
    end
    
    render :new
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

  def add_custom_error_message
    if Rails.env.development?
      # Simple error message in development
      @alert_message = "Invalid email or password. Please try again."
    else
      # Provide specific error messages based on remaining attempts in production
      attempts_left = MAX_ATTEMPTS - failed_attempts
      
      if attempts_left == 1
        @alert_message = "Invalid email or password. Warning: You have 1 more attempt before your account is temporarily locked."
      elsif attempts_left > 0
        @alert_message = "Invalid email or password. You have #{attempts_left} attempts remaining."
      else
        remaining_time = lockout_remaining_time
        @alert_message = "Too many failed login attempts. Your account is temporarily locked. Please try again in #{remaining_time} #{'minute'.pluralize(remaining_time)} or reset your password."
      end
    end
  end

  def handle_failed_login
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    add_custom_error_message
    render :new
  end

  def auth_options
    { scope: resource_name }
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