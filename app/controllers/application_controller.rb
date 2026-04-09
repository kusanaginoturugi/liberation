class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    return if current_user
    return if self.class.respond_to?(:allow_unauthenticated_actions) && self.class.allow_unauthenticated_actions.include?(action_name.to_sym)

    redirect_to User.exists? ? new_session_path : new_user_path
  end

  def start_session_for(user)
    reset_session
    session[:user_id] = user.id
  end

  def terminate_session
    reset_session
  end

  def self.allow_unauthenticated_access(only: nil)
    @allow_unauthenticated_actions = Array(only || action_methods).map(&:to_sym)
  end

  def self.allow_unauthenticated_actions
    @allow_unauthenticated_actions || []
  end
end
