class UsersController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  before_action :require_admin!, only: [:index]
  before_action :ensure_user_creation_allowed!, only: [:new, :create]
  before_action :load_regions, only: [:new, :create]

  def index
    @users = User.includes(:region).order(:id)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      @user.update_column(:admin, true) unless User.where.not(id: @user.id).exists?
      if User.where.not(id: @user.id).exists?
        redirect_to users_path, notice: "ユーザーを作成しました"
      else
        start_session_for(@user)
        redirect_to root_path, notice: "ユーザーを作成しました"
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    permitted = [:email, :password, :password_confirmation, :name, :region_id]
    permitted << :admin if current_user&.admin?
    params.require(:user).permit(*permitted)
  end

  def ensure_user_creation_allowed!
    return if !User.exists?
    return if current_user&.admin?

    redirect_to(current_user ? root_path : new_session_path)
  end

  def load_regions
    @regions = Region.order(:name)
  end
end
