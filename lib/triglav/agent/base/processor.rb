require 'parallel'
require 'connection_pool'

module Triglav::Agent
  module Base
    # Triglav agent processor class.
    #
    # An instance is created for a `resource_uri_prefix`.
    #
    # You usually do not need to customize this class, but if you want to
    # implement your original, configure
    #
    #     Triglav::Agent::Configuration.processor_class
    class Processor
      attr_reader :worker, :resource_uri_prefix

      def initialize(worker, resource_uri_prefix)
        @worker = worker
        @resource_uri_prefix = resource_uri_prefix
      end

      def self.max_consecuitive_error_count
        3
      end

      def process
        before_process
        success_count = 0
        consecutive_error_count = 0
        Parallel.each(resources, parallel_opts) do |resource|
          raise Parallel::Break if stopped?
          events = nil
          begin
            @connection_pool.with do |connection|
              monitor = monitor_class.new(connection, resource)
              monitor.process do |_events|
                events = _events
                $logger.info { "send_messages:#{events.map(&:to_hash).to_json}" }
                @api_client_pool.with {|api_client| api_client.send_messages(events) }
              end
            end
            @mutex.synchronize do
              success_count += 1
              consecutive_error_count = 0
            end
          rescue => e
            log_error(e)
            $logger.info { "failed_events:#{events.map(&:to_hash).to_json}" } if events
            @mutex.synchronize do
              raise TooManyError if (consecutive_error_count += 1) > self.class.max_consecuitive_error_count
            end
          end
        end
        success_count
      ensure
        after_process
      end

      def total_count
        resources.size
      end

      private

      def before_process
        @connection_pool = ConnectionPool.new(connection_pool_opts) {
          connection_class.new(get_connection_info(resource_uri_prefix))
        }
        @api_client_pool = ConnectionPool.new(connection_pool_opts) {
          ApiClient.new # renew connection
        }
        @mutex = Mutex.new
      end

      def after_process
        @connection_pool.shutdown {|conn| conn.close rescue nil }
        @api_client_pool.shutdown {|conn| conn.close rescue nil }
      end

      def connection_class
        Configuration.connection_class
      end

      def monitor_class
        Configuration.monitor_class
      end

      def name
        Configuration.name
      end

      def resources
        return @resources if @resources
        @resources = ApiClient.new.list_aggregated_resources(resource_uri_prefix) || []
        $logger.debug { "resource_uri_prefix:#{resource_uri_prefix} resources.size:#{@resources.size}" }
        @resources
      end

      def parallel_opts
        parallel_type == 'process' ? {in_processes: parallel_size} : {in_threads: parallel_size}
      end

      def connection_pool_opts
        {size: connection_pool_size, timeout: connection_pool_timeout}
      end

      def parallel_size
        $setting.dig(name, :parallel_size) || 1
      end

      def parallel_type
        $setting.dig(name, :parallel_type) || 'thread'
      end

      def connection_pool_size
        $setting.dig(name, :connection_pool_size) || parallel_size
      end

      def connection_pool_timeout
        $setting.dig(name, :connection_pool_timeout) || 60
      end

      def get_connection_info(resource_uri_prefix)
        $setting.dig(name, :connection_info)[resource_uri_prefix]
      end

      def log_error(e)
        $logger.error { "#{e.class} #{e.message} #{e.backtrace.join("\\n")}" } # one line
      end

      def stopped?
        worker.stopped? if worker and worker.respond_to?(:stopped?)
      end
    end
  end
end
