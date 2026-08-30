class SessionsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create, :destroy, :authentik, :callback ]

  def new
  end

  def create
    if AuthentikClient.configured?
      redirect_to new_session_path, alert: "Authentikでログインしてください"
      return
    end

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

  def authentik
    unless AuthentikClient.configured?
      redirect_to new_session_path, alert: "Authentikログインはまだ準備中です"
      return
    end

    state = SecureRandom.urlsafe_base64(32)
    session[:authentik_state] = state
    redirect_to AuthentikClient.authorization_url(state: state), allow_other_host: true
  end

  def callback
    unless valid_authentik_state?
      redirect_to new_session_path, alert: "Authentikログインの確認に失敗しました。もう一度お試しください"
      return
    end

    if params[:error].present?
      redirect_to new_session_path, alert: "Authentikログインを完了できませんでした"
      return
    end

    access_token = AuthentikClient.exchange_code(params[:code].to_s)
    user = authentik_user_from(AuthentikClient.userinfo(access_token))
    start_session_for(user, remember_me: false)
    redirect_to root_path, notice: "Authentikでログインしました"
  rescue AuthentikClient::Error => error
    redirect_to new_session_path, alert: error.message
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "ログアウトしました"
  end

  private

  AUTHENTIK_ADMIN_GROUPS = [ "liberation-admin", "myouou-admins" ].freeze
  AUTHENTIK_FELLOWSHIP_GROUPS = {
    "liberation-oedo" => "大江戸",
    "liberation-odaiba" => "お台場",
    "liberation-haneda" => "羽田",
    "liberation-kanagawa" => "かながわ",
    "liberation-fujisan" => "富士山",
    "liberation-sunten" => "駿天",
    "liberation-saitama" => "埼玉",
    "liberation-chiba" => "千葉",
    "liberation-yamanashi" => "山梨",
    "liberation-seimeiouin" => "聖明王院",
    "liberation-daibutsuden" => "大仏殿"
  }.merge(Fellowship::AVAILABLE_NAMES.to_h { |name| [ name, name ] }).freeze

  def valid_authentik_state?
    expected_state = session.delete(:authentik_state).to_s
    returned_state = params[:state].to_s
    expected_state.present? && returned_state.present? &&
      ActiveSupport::SecurityUtils.secure_compare(expected_state, returned_state)
  end

  def authentik_user_from(claims)
    subject = claims["sub"].to_s
    email = User.normalize_email(claims["email"])
    raise AuthentikClient::Error, "Authentikから利用者情報を受け取れませんでした" if subject.blank? || email.blank?

    admin, fellowship = authentik_permissions(claims["groups"])
    user = find_authentik_user(subject, email)
    user.assign_attributes(
      authentik_subject: subject,
      email: email,
      name: claims["name"].presence || claims["preferred_username"].presence || email,
      admin: admin,
      fellowship: fellowship
    )
    assign_default_region(user) if user.new_record?
    assign_random_password(user) if user.new_record?
    user.save!
    user
  rescue ActiveRecord::RecordInvalid => error
    raise AuthentikClient::Error, "利用者情報を保存できませんでした: #{error.record.errors.full_messages.to_sentence}"
  end

  def authentik_permissions(groups)
    group_names = Array(groups).map(&:to_s)
    admin = group_names.intersect?(AUTHENTIK_ADMIN_GROUPS)
    fellowship_names = group_names.filter_map { |group| AUTHENTIK_FELLOWSHIP_GROUPS[group] }.uniq
    return [ true, nil ] if admin

    raise AuthentikClient::Error, "Authentikで複数の伝道会が設定されています" if fellowship_names.many?

    fellowship = Fellowship.find_by(name: fellowship_names.first) if fellowship_names.one?
    return [ false, fellowship ] if fellowship.present?

    raise AuthentikClient::Error, "Authentikで管理者または担当伝道会が設定されていません"
  end

  def find_authentik_user(subject, email)
    user_by_subject = User.find_by(authentik_subject: subject)
    user_by_email = User.find_by(email: email)
    if user_by_subject && user_by_email && user_by_subject != user_by_email
      raise AuthentikClient::Error, "Authentikの利用者情報が既存の利用者と一致しません"
    end

    user_by_subject || user_by_email || User.new
  end

  def assign_default_region(user)
    user.region = Region.find_by(id: primary_region_id) || Region.order(:id).first
    raise AuthentikClient::Error, "利用者を登録するための聖院がありません" if user.region.blank?
  end

  def assign_random_password(user)
    password = SecureRandom.urlsafe_base64(32)
    user.password = password
    user.password_confirmation = password
  end

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
