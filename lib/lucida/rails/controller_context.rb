# frozen_string_literal: true

module Lucida
  module Rails
    # Included into ActionController::Base: layers the controller's current_user over the middleware context
    # (the middleware runs before authentication, so Devise's current_user is only reliable here).
    module ControllerContext
      def self.included(base)
        base.around_action :lucida_user_context
      end

      private

      def lucida_user_context(&)
        cfg = Lucida::Rails.config
        user = cfg.capture_user_context && respond_to?(cfg.current_user_method, true) ? send(cfg.current_user_method) : nil
        id = cfg.user_distinct_id(user)
        return yield unless id

        Lucida.with_context(distinct_id: id, &)
      end
    end
  end
end
