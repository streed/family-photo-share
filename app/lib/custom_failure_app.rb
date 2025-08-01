class CustomFailureApp < Devise::FailureApp
  def respond
    if http_auth?
      http_auth
    else
      redirect
    end
  end

  def redirect_url
    # Don't set any flash messages here - let our controllers handle it
    if warden_options[:scope]
      scope_url = send(:"new_#{warden_options[:scope]}_session_path")
      query_string = request.query_string.empty? ? "" : "?#{request.query_string}"
      scope_url + query_string
    else
      super
    end
  end

  private

  def redirect
    store_location!
    message = warden.message || warden_options[:message]

    # Don't set flash messages - our custom controllers will handle error messaging
    if request.format.html?
      redirect_to redirect_url
    elsif request.format.turbo_stream?
      redirect_to redirect_url, status: :see_other
    else
      redirect_to redirect_url
    end
  end
end
