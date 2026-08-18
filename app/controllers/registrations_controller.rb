class RegistrationsController < Devise::RegistrationsController
  before_action :set_invitation, only: [ :new, :create ]
  # Runs after set_invitation, so an invited person is already recognised by the
  # time we decide whether sign-up is open to them.
  before_action :ensure_signup_allowed, only: [ :new, :create ]

  def new
    # Allow both public signup and invitation-based signup
    super
  end

  def create
    if @invitation
      # Invitation-based signup
      super do |user|
        if user.persisted?
          # Accept the invitation and add user to family
          @invitation.accept!(user)
          # Clear the invitation token from session
          session.delete(:invitation_token)
          flash[:notice] = "Welcome to #{@invitation.family.name}! Your account has been created successfully."
        elsif user.errors.any?
          # Convert validation errors to a single flash message
          if user.errors[:email].any?
            flash.now[:alert] = "Email #{user.errors[:email].first}"
          elsif user.errors[:password].any?
            flash.now[:alert] = "Password #{user.errors[:password].first}"
          elsif user.errors[:password_confirmation].any?
            flash.now[:alert] = "Password confirmation #{user.errors[:password_confirmation].first}"
          else
            flash.now[:alert] = "Please correct the errors: #{user.errors.full_messages.first}"
          end
        end
      end
    else
      # Public signup - user creates account without joining a family
      super do |user|
        if user.persisted?
          flash[:notice] = "Welcome! Your account has been created. You can now create or join a family."
        elsif user.errors.any?
          # Convert validation errors to a single flash message
          if user.errors[:email].any?
            flash.now[:alert] = "Email #{user.errors[:email].first}"
          elsif user.errors[:password].any?
            flash.now[:alert] = "Password #{user.errors[:password].first}"
          elsif user.errors[:password_confirmation].any?
            flash.now[:alert] = "Password confirmation #{user.errors[:password_confirmation].first}"
          else
            flash.now[:alert] = "Please correct the errors: #{user.errors.full_messages.first}"
          end
        end
      end
    end
  end

  private

  # Creating an account is invitation-only unless the operator has opened it up.
  # Guarding the controller rather than the route means the flag takes effect on
  # restart with no route reload, and #edit / #update / #destroy — the signed-in
  # account screens Devise puts on the same controller — stay reachable.
  def ensure_signup_allowed
    return if @invitation.present? || PublicSignup.enabled?

    # 303 on a blocked POST, so Turbo and the browser follow it with a GET.
    # Everything else (GET the form, and the HEAD that shadows it) gets a plain 302.
    redirect_to new_user_session_path,
                alert: "New accounts are by invitation only. Ask someone in the family to invite you.",
                status: request.post? ? :see_other : :found
  end

  def set_invitation
    token = params[:invitation_token] || session[:invitation_token]
    if token
      @invitation = FamilyInvitation.find_by(token: token)
      if @invitation.nil? || @invitation.expired? || !@invitation.pending?
        session.delete(:invitation_token)
        redirect_to root_path, alert: "Invalid or expired invitation."
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
      # Invitation-based signup goes to family page
      family_path(@invitation.family)
    else
      # Public signup goes to families index to create or join a family
      families_path
    end
  end
end
