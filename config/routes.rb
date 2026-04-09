Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  resource :session, only: [:new, :create, :destroy]
  resource :settings, only: [:edit, :update]
  resources :users, only: [:index, :new, :create]
  resources :regions, only: [:index, :edit, :update]
  resources :events, only: [:index, :new, :create, :edit, :update] do
    resources :event_details, only: [:index, :edit, :update]
  end
  resources :evangelism_meetings, only: [:index, :new, :create, :edit, :update]
  root "chobatsu_reports#index"
  resources :chobatsu_reports, only: [:index, :new, :create] do
    collection do
      get :export
      get :summary
    end
  end
end
