# The test environment uses a real (in-memory) cache store so that the login and
# guest-album rate limiters are exercisable. That store is shared across
# examples, so clear it between them to keep failed-attempt counters isolated.
RSpec.configure do |config|
  config.before(:each) do
    Rails.cache.clear
  end
end
