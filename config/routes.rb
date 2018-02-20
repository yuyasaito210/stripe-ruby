Rails.application.routes.draw do
  resources :charges, only: [:new, :create]
  resources :subscriptions, only: [:new, :create]
  devise_for :users
  post 'subscription_checkout' => 'subscriptions#subscription_checkout'
  post 'webhooks' => 'subscriptions#webhooks'
  get 'plans' => 'subscriptions#plans'
  root to: 'charges#new'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
