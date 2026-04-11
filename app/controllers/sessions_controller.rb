class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :destroy ]

  def new
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase.strip)

    if user&.authenticate(params[:password])
      start_session_for(user)
      redirect_to root_path, notice: "ログインしました"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが正しくありません"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "ログアウトしました"
  end
end
