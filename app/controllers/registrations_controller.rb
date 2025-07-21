class RegistrationsController < Devise::RegistrationsController
  before_action :check_invitation_token, only: [:new, :create]
  before_action :set_invitation, only: [:new, :create]

  def new
    redirect_to root_path, alert: 'Registration is by invitation only.' unless @invitation
    super
  end

  def create
    if @invitation
      super do |user|
        if user.persisted?
          # Accept the invitation and add user to family
          @invitation.accept!(user)
          # Clear the invitation token from session
          session.delete(:invitation_token)
        end
      end
    else
      redirect_to root_path, alert: 'Registration is by invitation only.'
    end
  end

  private

  def check_invitation_token
    token = params[:invitation_token] || session[:invitation_token]
    unless token
      redirect_to root_path, alert: 'Registration is by invitation only.'
    end
  end

  def set_invitation
    token = params[:invitation_token] || session[:invitation_token]
    if token
      @invitation = FamilyInvitation.find_by(token: token)
      if @invitation.nil? || @invitation.expired? || !@invitation.pending?
        session.delete(:invitation_token)
        redirect_to root_path, alert: 'Invalid or expired invitation.'
      else
        # Store token in session for the registration process
        session[:invitation_token] = token
        # Pre-fill email if available
        if resource.nil?
          self.resource = resource_class.new(email: @invitation.email)
        end
      end
    end
  end

  def after_sign_up_path_for(resource)
    if @invitation
      family_path(@invitation.family)
    else
      super
    end
  end
end