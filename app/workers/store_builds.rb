class StoreBuilds
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  sidekiq_options backtrace: true,
                  retry: false

  recurrence do
    minutely(5)
  end

  def perform

  end
end
