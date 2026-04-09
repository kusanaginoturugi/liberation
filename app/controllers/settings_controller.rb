class SettingsController < ApplicationController
  before_action :require_admin!

  def edit
    @gradient_enabled = SystemSetting.gradient_enabled?
    @number_shadow_enabled = SystemSetting.number_shadow_enabled?
  end

  def update
    save_boolean_setting(SystemSetting::GRADIENT_ENABLED_KEY, settings_params[:gradient_enabled])
    save_boolean_setting(SystemSetting::NUMBER_SHADOW_ENABLED_KEY, settings_params[:number_shadow_enabled])

    redirect_to edit_settings_path, notice: "設定を更新しました"
  end

  private

  def settings_params
    params.require(:settings).permit(:gradient_enabled, :number_shadow_enabled)
  end

  def save_boolean_setting(key, value)
    setting = SystemSetting.find_or_initialize_by(key: key)
    setting.value = ActiveModel::Type::Boolean.new.cast(value).to_s
    setting.save!
  end
end
