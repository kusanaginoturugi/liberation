Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "chobatsu_reports#new"
  resources :chobatsu_reports, only: [:new, :create]
end
