class FamiliesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_family, only: [ :show, :edit, :update, :destroy, :members, :leave ]
  before_action :ensure_member, only: [ :show, :members, :leave ]
  before_action :ensure_admin, only: [ :edit, :update, :destroy ]

  def index
    if current_user.has_family?
      redirect_to family_path(current_user.family)
    else
      @pending_invitations = current_user.pending_invitations.includes(:family)
    end
  end

  def show
    @recent_photos = @family.recent_photos(12)
    @members = @family.family_memberships.includes(:user).recent
    @pending_invitations = @family.family_invitations.pending.recent
  end

  def new
    if current_user.has_family?
      redirect_to family_path(current_user.family), alert: "You already belong to a family."
    else
      @family = Family.new
    end
  end

  def edit
  end
  def create
    if current_user.has_family?
      redirect_to family_path(current_user.family), alert: "You already belong to a family."
      return
    end

    @family = current_user.created_families.build(family_params)

    if @family.save
      redirect_to @family, notice: "Family was successfully created!"
    else
      handle_validation_errors(@family)
      render :new, status: :unprocessable_entity
    end
  end


  def update
    if @family.update(family_params)
      redirect_to @family, notice: "Family was successfully updated!"
    else
      handle_validation_errors(@family)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    begin
      @family.destroy!
      redirect_to families_path, notice: "Family was successfully deleted!"
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to @family, alert: "Unable to delete family. Please ensure all members have left first."
    end
  end

  def members
    @members = @family.family_memberships.includes(:user).recent
    @pending_invitations = @family.family_invitations.pending.recent
  end

  def leave
    begin
      membership = @family.family_memberships.find_by(user: current_user)

      unless membership
        redirect_to root_path, alert: "You are not a member of this family."
        return
      end

      if membership.admin? && @family.family_memberships.admins.count == 1
        redirect_to @family, alert: "You cannot leave as you are the only admin. Transfer admin rights first or delete the family."
      else
        membership.destroy!
        redirect_to root_path, notice: "You have left the family."
      end
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to @family, alert: "Unable to leave family. Please try again."
    end
  end

  private

  def set_family
    @family = Family.find(params[:id])
  end

  def ensure_member
    redirect_to families_path, alert: "You are not a member of this family." unless @family.member?(current_user)
  end

  def ensure_admin
    redirect_to @family, alert: "Only family admins can perform this action." unless @family.admin?(current_user)
  end

  def family_params
    params.require(:family).permit(:name, :description)
  end
end
