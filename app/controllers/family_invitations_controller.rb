class FamilyInvitationsController < ApplicationController
  before_action :authenticate_user!, except: [:show, :accept, :decline]
  before_action :set_family, only: [:new, :create, :destroy]
  before_action :ensure_admin, only: [:new, :create, :destroy]
  before_action :set_invitation_by_token, only: [:show, :accept, :decline]

  def new
    @invitation = @family.family_invitations.build
    @pending_invitations = @family.family_invitations.pending.recent
  end

  def create
    @invitation = @family.family_invitations.build(invitation_params)
    @invitation.inviter = current_user
    
    if @invitation.save
      begin
        # Send invitation email
        FamilyInvitationMailer.invitation_email(@invitation).deliver_now
        redirect_to new_family_invitation_path(@family), notice: 'Invitation sent successfully!'
      rescue => e
        @invitation.destroy
        redirect_to new_family_invitation_path(@family), alert: 'Unable to send invitation email. Please try again.'
      end
    else
      handle_validation_errors(@invitation)
      @pending_invitations = @family.family_invitations.pending.recent
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @invitation = @family.family_invitations.find(params[:id])
      @invitation.destroy!
      redirect_to new_family_invitation_path(@family), notice: 'Invitation cancelled.'
    rescue ActiveRecord::RecordNotFound
      redirect_to new_family_invitation_path(@family), alert: 'Invitation not found.'
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to new_family_invitation_path(@family), alert: 'Unable to cancel invitation.'
    end
  end

  def show
    redirect_to root_path, alert: 'Invalid invitation.' if @invitation.nil?
    
    if @invitation.expired?
      @invitation.expire!
      redirect_to root_path, alert: 'This invitation has expired.'
    elsif @invitation.accepted?
      redirect_to family_path(@invitation.family), notice: 'You are already a member of this family.'
    elsif @invitation.declined?
      redirect_to root_path, alert: 'This invitation has been declined.'
    end
  end

  def accept
    if user_signed_in?
      if current_user.has_family?
        redirect_to root_path, alert: 'You already belong to a family.'
      elsif current_user.email == @invitation.email
        if @invitation.accept!(current_user)
          redirect_to family_path(@invitation.family), notice: 'Welcome to the family!'
        else
          redirect_to root_path, alert: 'Unable to accept invitation.'
        end
      else
        redirect_to root_path, alert: 'This invitation is for a different email address.'
      end
    else
      session[:invitation_token] = @invitation.token
      redirect_to new_user_session_path, notice: 'Please sign in or create an account to accept the invitation.'
    end
  end

  def decline
    if @invitation.decline!
      redirect_to root_path, notice: 'Invitation declined.'
    else
      redirect_to root_path, alert: 'Unable to decline invitation.'
    end
  end

  private

  def set_family
    @family = Family.find(params[:family_id])
  end

  def set_invitation_by_token
    @invitation = FamilyInvitation.find_by(token: params[:token])
  end

  def ensure_admin
    redirect_to @family, alert: 'Only family admins can manage invitations.' unless @family.admin?(current_user)
  end

  def invitation_params
    params.require(:family_invitation).permit(:email)
  end
end
