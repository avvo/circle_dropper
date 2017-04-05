Rails.application.routes.draw do
  require 'sidetiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
