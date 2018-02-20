Rails.application.routes.draw do
  resources :charges, only: [:new, :create]
  devise_for :users
  root to: 'charges#new'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
