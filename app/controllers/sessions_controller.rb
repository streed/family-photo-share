class SessionsController < Devise::SessionsController
  # Maximum number of failed attempts before lockout
  MAX_ATTEMPTS = 5
  # Lockout duration in minutes
  LOCKOUT_DURATION = 15

  def create
    # Check if user is locked out before attempting authentication (skip in development)
    if !Rails.env.development? && rate_limit_exceeded?
      # Same wording as the message shown on the attempt that trips the limit,
      # so a locked-out user doesn't get two different explanations.
      flash.now[:alert] = lockout_message
      self.resource = resource_class.new(sign_in_params)
      clean_up_passwords(resource)
      render :new, status: :too_many_requests and return
    end

    # Store email before attempting authentication
    attempted_email = params.dig(:user, :email)

    # Non-bang authenticate: the bang version throws :warden, which Warden's
    # middleware hands to CustomFailureApp, so a rescue here would never run and
    # a failed sign-in produced no message at all.
    self.resource = warden.authenticate(auth_options)

    if resource&.persisted?
      # Successful authentication
      clear_failed_attempts unless Rails.env.development?
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, resource)
      yield resource if block_given?
      respond_with resource, location: after_sign_in_path_for(resource)
    else
      handle_failed_login(attempted_email)
    end
  end

  private

  def handle_failed_login(attempted_email)
    increment_failed_attempts unless Rails.env.development?

    # Redisplay the form with the email they typed, but never the password.
    self.resource = resource_class.new(email: attempted_email)
    clean_up_passwords(resource)

    # The layout renders flash (including flash.now), so the message has to live
    # there — the sessions/new view never reads @alert_message.
    flash.now[:alert] = failed_login_message

    render :new, status: :unprocessable_content
  end

  def failed_login_message
    return "Invalid email or password. Please try again." if Rails.env.development?

    attempts_left = MAX_ATTEMPTS - failed_attempts

    if attempts_left == 1
      "Invalid email or password. Warning: You have 1 more attempt before your account is temporarily locked."
    elsif attempts_left > 0
      "Invalid email or password. You have #{attempts_left} attempts remaining."
    else
      lockout_message
    end
  end

  def lockout_message
    remaining_time = lockout_remaining_time
    "Too many failed login attempts. Your account is temporarily locked. " \
      "Please try again in #{remaining_time} #{'minute'.pluralize(remaining_time)} or reset your password."
  end

  def rate_limit_key
    "login_attempts:#{request.remote_ip}"
  end

  def rate_limit_exceeded?
    failed_attempts >= MAX_ATTEMPTS
  end

  def failed_attempts
    data = Rails.cache.read(rate_limit_key)
    return 0 unless data.is_a?(Hash)
    data[:count] || 0
  end

  def lockout_remaining_time
    data = Rails.cache.read(rate_limit_key)
    return 0 unless data.is_a?(Hash) && data[:first_attempt_at]

    elapsed = Time.current - Time.parse(data[:first_attempt_at])
    remaining_seconds = (LOCKOUT_DURATION.minutes - elapsed).to_i
    return 0 if remaining_seconds <= 0
    (remaining_seconds / 60.0).ceil
  end

  def increment_failed_attempts
    data = Rails.cache.read(rate_limit_key)
    if data.is_a?(Hash)
      count = data[:count] + 1
    else
      count = 1
    end
    Rails.cache.write(rate_limit_key,
      { count: count, first_attempt_at: data.is_a?(Hash) ? data[:first_attempt_at] : Time.current.to_s },
      expires_in: LOCKOUT_DURATION.minutes)
  end

  def clear_failed_attempts
    Rails.cache.delete(rate_limit_key)
  end

  def auth_options
    { scope: resource_name }
  end

  protected

  def rate_limit_info
    {
      failed_attempts: failed_attempts,
      remaining_attempts: [ MAX_ATTEMPTS - failed_attempts, 0 ].max,
      locked_out: rate_limit_exceeded?,
      lockout_remaining_minutes: lockout_remaining_time
    }
  end
  helper_method :rate_limit_info
end
