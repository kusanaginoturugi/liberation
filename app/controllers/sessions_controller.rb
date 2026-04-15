class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :destroy ]

  def new
  end

  def create
    login_id = params[:login_id].to_s.unicode_normalize(:nfkc).gsub(/\s+/, "")
    password = params[:password].to_s
    user = User.find_by(login_id: login_id)

    if login_id.blank? || password.blank?
      flash.now[:alert] = missing_login_field_message(login_id, password)
      render :new, status: :unprocessable_content
    elsif user&.authenticate(password)
      start_session_for(user, remember_me: remember_me?)
      redirect_to root_path, notice: "ログインしました"
    else
      flash.now[:alert] = invalid_login_message
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "ログアウトしました"
  end

  private

  def remember_me?
    params[:remember_me] != "0"
  end

  def missing_login_field_message(login_id, password)
    return "ログインIDとパスワードを入力してください" if login_id.blank? && password.blank?
    return "ログインIDを入力してください" if login_id.blank?

    "パスワードを入力してください"
  end

  def invalid_login_message
    "ログインIDまたはパスワードが正しくありません。ログインIDの全角文字や空白は自動で補正しています。"
  end
end
