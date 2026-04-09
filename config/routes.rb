Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  resource :session, only: [:new, :create, :destroy]
  resources :users, only: [:new, :create]
  root "chobatsu_reports#new"
  resources :chobatsu_reports, only: [:new, :create]
end
