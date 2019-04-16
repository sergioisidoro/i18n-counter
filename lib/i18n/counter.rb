require 'i18n'
require 'i18n/tasks'
require 'async/redis'
require 'redis'
require "i18n/counter/version"
require "i18n/counter/summary"

module I18n
  module Counter

    DEFAULT_LOCALE = 'en'

    module I18nRedis
      class << self
        attr_accessor :async_redis
        attr_accessor :redis

        def ready?
          determine_redis_provider
        end

        def async_connection
          @async_redis ||= Async::Redis::Client.new(determine_redis_provider)
        end

        def connection
          @redis ||= Redis.new(url: determine_redis_provider)
        end

        def determine_redis_provider
          ENV['I18N_REDIS_URL'] || ENV[ENV['REDIS_PROVIDER'] || 'REDIS_URL']
        end
      end
    end

    module Hook
      def lookup(locale, key, scope = [], options = {})

        if !I18n::Counter.enabled? || !I18nRedis.ready?
          return super
        end

        Async.run do
          separator = options[:separator] || I18n.default_separator
          flat_key = I18n.normalize_keys(locale, key, scope, separator).join(separator)
          I18nRedis.async_connection.incr(flat_key)
        end

        super
      end
    end

    def self.enabled?
      ENV['ENABLE_I18N_COUNTER'] == 'true'
    end
  end
  Backend::Simple.prepend(Counter::Hook)
end
