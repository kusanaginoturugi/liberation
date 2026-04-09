class SettingsController < ApplicationController
  before_action :require_admin!

  def edit
    @gradient_enabled = SystemSetting.gradient_enabled?
  end

  def update
    setting = SystemSetting.find_or_initialize_by(key: SystemSetting::GRADIENT_ENABLED_KEY)
    setting.value = ActiveModel::Type::Boolean.new.cast(settings_params[:gradient_enabled]).to_s
    setting.save!

    redirect_to edit_settings_path, notice: "設定を更新しました"
  end

  private

  def settings_params
    params.require(:settings).permit(:gradient_enabled)
  end
end
