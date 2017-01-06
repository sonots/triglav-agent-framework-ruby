module Triglav
  module Agent
    # Configure Triglav::Agent framework
    #
    #    require 'triglav/agent/configuration'
    #    require 'triglav/agent/vertica/worker'
    #    Triglav::Agent::Configuration.configure do |config|
    #      config.cli_class = Triglav::Agent::Vertica::CLI
    #      config.setting_class = Triglav::Agent::Vertica::Setting
    #      config.worker_module = Triglav::Agent::Vertica::Worker
    #      config.name = :vertica
    #    end
    #    Triglav::Agent::Configuration.cli_class.new.run
    class Configuration
      def self.configure(&block)
        yield(Triglav::Agent::Configuration)
      end

      def self.worker_module
        @worker_module ||= Triglav::Agent::Base::Worker
      end

      def self.setting_class
        @setting_class ||= Triglav::Agent::Base::Setting
      end

      def self.cli_class
        @cli_class ||= Triglav::Agent::Base::CLI
      end

      def self.name
        @name ||= 'agent'
      end

      def self.worker_module=(worker_module)
        @worker_module = worker_module
      end

      def self.setting_class=(setting_class)
        @setting_class = setting_class
      end

      def self.cli_class=(cli_class)
        @cli_class = cli_class
      end

      def self.name=(name)
        @name = name
      end
    end
  end
end
