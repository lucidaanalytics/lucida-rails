# lucida-rails

Rails integration for the [`lucida`](../ruby) server gem: a Railtie, a Rack middleware that sets the request context,
and an install generator.

## Install

From GitHub, [lucidaanalytics/lucida-rails](https://github.com/lucidaanalytics/lucida-rails), release `v0.1.0` (neither gem is on RubyGems yet; the registry install is coming):

```ruby
# Gemfile
gem "lucida", git: "https://github.com/lucidaanalytics/lucida-ruby.git", tag: "v0.1.0"
gem "lucida-rails", git: "https://github.com/lucidaanalytics/lucida-rails.git", tag: "v0.1.0"
```

```sh
bin/rails g lucida:install   # writes config/initializers/lucida.rb
```

```ruby
Lucida::Rails.configure do |c|
  c.api_key = ENV["LUCIDA_API_KEY"]
  c.secret_key = ENV["LUCIDA_SECRET_KEY"]   # optional: local flag evaluation, polled in the background
  c.use_tracing_headers = true              # adopt X-Lucida-Distinct-Id / X-Lucida-Session-Id from the browser SDK
  c.capture_user_context = true             # signed-in user becomes the distinct id
  c.current_user_method = :current_user     # called on the controller (and Warden's user in the middleware)
  c.user_id_method = :id                    # called on that user
  c.trust_proxy = false                     # true: $ip from the first X-Forwarded-For entry
  c.client_options = {}                     # anything Lucida::Client accepts (on_error:, before_send:, ...)
end
```

## What it does

- `Lucida::Rails::Middleware` wraps every request in `Lucida.with_context`: distinct id (signed-in user via Warden/Devise,
  else the tracing header), `$session_id` from the tracing header, and `$current_url`, `$request_method`,
  `$request_path`, `$user_agent`, `$ip`. An `around_action` in `ActionController::Base` then layers `current_user` (the
  middleware runs before most apps authenticate). Explicit arguments always win.
- The tracing headers are client-controlled: never use them for authentication.
- `Lucida::Rails.capture / identify / alias / group_identify / flush / get_feature_flag / is_feature_enabled / ...`
  delegate to the process-wide `Lucida.client`, built from the config after initializers run. Without an `api_key` the client is
  disabled (nothing is sent), so development works unconfigured. Pass `nil` as the distinct id to use the request context.
- Forking servers: the Railtie calls `Lucida.after_fork` through `ActiveSupport::ForkTracker`; the client also recovers on its own after a pid change. The client is flushed at exit.

```ruby
Lucida::Rails.capture(nil, "checkout_started", { "total" => 12 })
```

## Tests

`make sdk-rails` (`ruby -I../ruby/lib -Ilib test/rails_test.rb`). The middleware, configuration, delegation and controller
concern are tested with plain Rack envs and stubs. The Railtie and generator tests run only when the `rails` gem is
installed and skip otherwise; they check that the Railtie class loads and that the generator writes the initializer,
not a full booted application.

---

This repository is a read-only mirror of the Lucida monorepo (synced by a script, never edited by hand); releases and provenance attestations are built here by GitHub Actions. Issues are welcome, changes land upstream.
