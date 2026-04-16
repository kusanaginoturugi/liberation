class UsersController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  before_action :require_admin!, only: [ :index ]
  before_action :ensure_user_creation_allowed!, only: [ :new, :create ]
  before_action :set_user, only: [ :edit, :update ]
  before_action :authorize_user_edit!, only: [ :edit, :update ]
  before_action :load_regions, only: [ :new, :create, :edit, :update ]

  def index
    @users = User.includes(:region).order(:id)
  end

  def new
    @user = User.new
  end

  def edit
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

  def update
    if @user.update(user_update_params)
      if @user == current_user
        redirect_to root_path, notice: "プロフィールを更新しました"
      else
        redirect_to users_path, notice: "ユーザーを更新しました"
      end
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def authorize_user_edit!
    return if current_user&.admin?
    return if @user == current_user

    redirect_to root_path, alert: "編集権限がありません"
  end

  def user_params
    attrs = params.require(:user).permit(:email, :password, :password_confirmation, :name, :region_id)
    attrs[:admin] = admin_flag_param if current_user&.admin?
    attrs
  end

  def user_update_params
    permitted = [ :login_id, :email, :name, :password, :password_confirmation ]
    permitted << :region_id if current_user&.admin?
    attrs = params.require(:user).permit(*permitted)
    attrs[:admin] = admin_flag_param if current_user&.admin? && @user != current_user
    if attrs[:password].blank?
      attrs.delete(:password)
      attrs.delete(:password_confirmation)
    end
    attrs
  end

  def ensure_user_creation_allowed!
    return if !User.exists?
    return if current_user&.admin?

    redirect_to(current_user ? root_path : new_session_path)
  end

  def load_regions
    @regions = Region.order(:name)
  end

  def admin_flag_param
    ActiveModel::Type::Boolean.new.cast(params.dig(:user, :admin))
  end
end
