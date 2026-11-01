# frozen_string_literal: true

module Lucida
  module Rails
    # Rack middleware: wraps each request in Lucida.with_context (tracing headers, signed-in user via Warden/Devise,
    # request props). ControllerContext refines the distinct id with current_user once the controller runs.
    class Middleware
      def initialize(app, config = nil)
        @app = app
        @config = config
      end

      def call(env)
        Lucida.with_context(**context_for(env)) { @app.call(env) }
      end

      def context_for(env)
        cfg = @config || Lucida::Rails.config
        traced = cfg.use_tracing_headers ? Lucida.context_from_headers(env) : {}
        id = cfg.user_distinct_id(warden_user(env)) || traced[:distinct_id]
        { distinct_id: id, session_id: traced[:session_id], properties: request_props(env, cfg) }
      end

      private

      def warden_user(env)
        env["warden"]&.user
      rescue StandardError
        nil
      end

      def request_props(env, cfg)
        host = env["HTTP_HOST"] || env["SERVER_NAME"]
        path = env["PATH_INFO"].to_s
        { "$current_url" => "#{env['rack.url_scheme'] || 'http'}://#{host}#{path}", "$request_method" => env["REQUEST_METHOD"],
          "$request_path" => path, "$user_agent" => env["HTTP_USER_AGENT"], "$ip" => client_ip(env, cfg) }.compact
      end

      def client_ip(env, cfg)
        fwd = cfg.trust_proxy ? env["HTTP_X_FORWARDED_FOR"].to_s.split(",").first.to_s.strip : ""
        fwd.empty? ? env["REMOTE_ADDR"] : fwd
      end
    end
  end
end
