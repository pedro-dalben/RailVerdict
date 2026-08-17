# frozen_string_literal: true
Rails.application.routes.draw do
  resources :users do
    member do
      get :custom
    end
  end
  draw :additional
  mount Engine, at: "/engine"
end
