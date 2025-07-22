module GuestSessionTracking
  extend ActiveSupport::Concern
  
  included do
    before_action :track_guest_activity, if: :guest_session_active?
  end
  
  private
  
  def guest_session_active?
    @current_guest_session.present?
  end
  
  def track_guest_activity
    return unless @current_guest_session
    
    # Extend session on any activity
    @current_guest_session.extend_session!
    
    # Update session expiration in cookie for JavaScript countdown
    cookies[:guest_session_expires_at] = {
      value: @current_guest_session.expires_at.to_i.to_s,
      expires: @current_guest_session.expires_at,
      httponly: false # Allow JavaScript access for countdown
    }
  end
  
  def set_guest_session_info
    return unless @current_guest_session
    
    @session_expires_in_seconds = @current_guest_session.expires_in_seconds
    @session_expires_in_minutes = @current_guest_session.expires_in_minutes
  end
end