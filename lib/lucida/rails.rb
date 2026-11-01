# frozen_string_literal: true

require "lucida"
require_relative "rails/configuration"
require_relative "rails/middleware"
require_relative "rails/controller_context"

module Lucida
  # Rails integration: Railtie, Rack middleware (request context) and delegation to the process-wide client.
  module Rails
    DELEGATED = %i[capture identify alias group_identify flush get_feature_flag is_feature_enabled
                   get_feature_flag_payload get_all_flags get_feature_flag_result].freeze

    class << self
      def config = (@config ||= Configuration.new)

      def configure
        yield config
        config
      end

      def client = (Lucida.client ||= config.build_client)

      DELEGATED.each do |m|
        define_method(m) { |*args, **kw, &blk| client.public_send(m, *args, **kw, &blk) }
      end
    end
  end
end

require_relative "rails/railtie" if defined?(::Rails::Railtie)
