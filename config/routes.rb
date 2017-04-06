Rails.application.routes.draw do
  require 'sidetiq/web'
  mount Sidekiq::Web => '/sidekiq'

  root to: redirect('/sidekiq')
end
