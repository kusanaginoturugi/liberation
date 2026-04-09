Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  resource :session, only: [:new, :create, :destroy]
  resources :users, only: [:new, :create]
  resources :regions, only: [:index, :edit, :update]
  resources :events, only: [:index, :edit, :update]
  resources :evangelism_meetings, only: [:index, :edit, :update]
  root "chobatsu_reports#index"
  resources :chobatsu_reports, only: [:index, :new, :create] do
    collection do
      get :summary
    end
  end
end
