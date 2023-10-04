Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  resources :actresses do
    member do
      get :delete
    end
  end

  resources :clips do
    member do
      get :delete
    end
  end

  end
