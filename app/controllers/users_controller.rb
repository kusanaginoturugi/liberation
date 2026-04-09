class UsersController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]

  before_action :redirect_if_users_exist, only: [:new, :create]

  def new
    @user = User.new
    @regions = Region.order(:name)
  end

  def create
    @user = User.new(user_params)
    @regions = Region.order(:name)

    if @user.save
      @user.update_column(:admin, true) unless User.where.not(id: @user.id).exists?
      start_session_for(@user)
      redirect_to root_path, notice: "ユーザーを作成しました"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :region_id)
  end

  def redirect_if_users_exist
    redirect_to new_session_path if User.exists?
  end
end
