# frozen_string_literal: true

module Lucida
  module Rails
    class Configuration
      # Client credentials / options (passed through to Lucida::Client).
      attr_accessor :api_key, :host, :secret_key, :client_options
      # use_tracing_headers: adopt X-Lucida-Distinct-Id / X-Lucida-Session-Id from the browser SDK.
      # capture_user_context: use the signed-in user (current_user_method -> user_id_method) as distinct id.
      # trust_proxy: take $ip from the first X-Forwarded-For entry instead of REMOTE_ADDR.
      attr_accessor :use_tracing_headers, :capture_user_context, :current_user_method, :user_id_method, :trust_proxy

      def initialize
        @host = nil
        @client_options = {}
        @use_tracing_headers = true
        @capture_user_context = true
        @current_user_method = :current_user
        @user_id_method = :id
        @trust_proxy = false
      end

      def build_client
        opts = client_options.dup
        opts[:host] = host if host
        opts[:secret_key] = secret_key if secret_key
        key = api_key.to_s
        Lucida::Client.new(key, **opts, disabled: key.empty? || opts[:disabled])
      end

      # The distinct id for `user` (nil when there is no user or the id method is missing/blank).
      def user_distinct_id(user)
        return nil unless capture_user_context && user && user.respond_to?(user_id_method)

        id = user.public_send(user_id_method).to_s
        id.empty? ? nil : id
      end
    end
  end
end
