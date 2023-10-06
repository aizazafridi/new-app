Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  root 'home#index'
  get 'home/browse_ac'
  get 'home/browse_cl'
  get 'home/search_cl/:tag', to: 'home#search_cl'
  get '/home/clip/:id', to: 'home#clip'
  get '/home/actress/:id', to: 'home#actress'
  get '/home/report_link/:id', to: 'home#report_link'
  get '/home/about', to: 'home#about'
  get '/home/request_clip', to: 'home#request_clip'
  get '/home/index2', to: 'home#index2'
  get '/clips/broken_links_index', to: 'clips#broken_links_index'
  get '/actresses/reg', to: 'actresses#reg'
  get '/home/count/:id', to: 'home#count'

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
