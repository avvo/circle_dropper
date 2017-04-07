sidekiq_config = Rails.application.config_for(:sidekiq)

Sidekiq.configure_client do |config|
  config.redis = sidekiq_config
end

Sidekiq.configure_server do |config|
  config.redis = sidekiq_config
end

Redis.current = Sidekiq.redis {|c| c}

if Rails.configuration.x.sidekiq_inline
  require 'sidekiq/testing'
  Sidekiq::Testing.inline!
end
