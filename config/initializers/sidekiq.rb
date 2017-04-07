sidekiq_config = Rails.application.config_for(:sidekiq)

if Rails.configuration.x.test_redis
  require 'avvo_test_redis'
  $avvo_test_redis = AvvoTestRedis::Server.new.start
  sidekiq_config['url'] = $avvo_test_redis.client.id
end

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
