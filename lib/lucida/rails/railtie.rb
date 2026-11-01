# frozen_string_literal: true

module Lucida
  module Rails
    class Railtie < ::Rails::Railtie
      initializer "lucida.middleware" do |app|
        app.middleware.use Lucida::Rails::Middleware
      end

      initializer "lucida.controller_context" do
        ActiveSupport.on_load(:action_controller) { include Lucida::Rails::ControllerContext }
      end

      # The initializer file (rails g lucida:install) configures; the client is built after it ran.
      config.after_initialize do
        Lucida.client ||= Lucida::Rails.config.build_client
        # Puma cluster / Spring forks: threads do not survive fork(2).
        ActiveSupport::ForkTracker.after_fork { Lucida.after_fork } if defined?(ActiveSupport::ForkTracker)
        at_exit { Lucida.client&.shutdown }
      end
    end
  end
end
