# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "tmpdir"
require "lucida/rails"

# Run: ruby -I../ruby/lib -Ilib test/rails_test.rb  (no Rails needed; the Railtie/generator tests skip without it)
class MiddlewareTest < Minitest::Test
  User = Struct.new(:id)

  def setup
    @cfg = Lucida::Rails::Configuration.new
    @seen = nil
    @app = lambda { |_env|
      @seen = Lucida.current_context
      [200, {}, ["ok"]]
    }
  end

  def call(env, cfg = @cfg)
    base = { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/pricing", "HTTP_HOST" => "example.com",
             "rack.url_scheme" => "https", "REMOTE_ADDR" => "10.0.0.1", "HTTP_USER_AGENT" => "UA" }
    Lucida::Rails::Middleware.new(@app, cfg).call(base.merge(env))
  end

  def test_sets_context_from_tracing_headers_and_request
    status, = call("HTTP_X_LUCIDA_DISTINCT_ID" => "anon1", "HTTP_X_LUCIDA_SESSION_ID" => "s9")
    assert_equal 200, status
    assert_equal ["anon1", "s9"], [@seen[:distinct_id], @seen[:session_id]]
    assert_equal({ "$current_url" => "https://example.com/pricing", "$request_method" => "GET", "$request_path" => "/pricing",
                   "$user_agent" => "UA", "$ip" => "10.0.0.1" }, @seen[:properties])
    assert_empty Lucida::Context.stack
  end

  def test_tracing_headers_can_be_disabled
    @cfg.use_tracing_headers = false
    call("HTTP_X_LUCIDA_DISTINCT_ID" => "anon1")
    assert_nil @seen[:distinct_id]
  end

  def test_warden_user_beats_tracing_header
    warden = Struct.new(:user).new(User.new(42))
    call({ "warden" => warden, "HTTP_X_LUCIDA_DISTINCT_ID" => "anon1" })
    assert_equal "42", @seen[:distinct_id]
    @cfg.capture_user_context = false
    call({ "warden" => warden, "HTTP_X_LUCIDA_DISTINCT_ID" => "anon1" })
    assert_equal "anon1", @seen[:distinct_id]
  end

  def test_trust_proxy_uses_first_forwarded_for
    call("HTTP_X_FORWARDED_FOR" => "1.2.3.4, 5.6.7.8")
    assert_equal "10.0.0.1", @seen[:properties]["$ip"]
    @cfg.trust_proxy = true
    call("HTTP_X_FORWARDED_FOR" => "1.2.3.4, 5.6.7.8")
    assert_equal "1.2.3.4", @seen[:properties]["$ip"]
  end

  def test_context_is_popped_when_app_raises
    @app = ->(_e) { raise "boom" }
    assert_raises(RuntimeError) { call({}) }
    assert_empty Lucida::Context.stack
  end
end

class ConfigAndDelegationTest < Minitest::Test
  def test_defaults
    c = Lucida::Rails::Configuration.new
    assert_equal [true, true, :current_user, :id, false],
                 [c.use_tracing_headers, c.capture_user_context, c.current_user_method, c.user_id_method, c.trust_proxy]
  end

  def test_user_distinct_id_custom_method_and_blank
    c = Lucida::Rails::Configuration.new
    c.user_id_method = :uuid
    assert_equal "u-1", c.user_distinct_id(Struct.new(:uuid).new("u-1"))
    assert_nil c.user_distinct_id(Struct.new(:uuid).new(""))
    assert_nil c.user_distinct_id(Object.new)
    assert_nil c.user_distinct_id(nil)
  end

  def test_blank_api_key_builds_disabled_client_and_delegation_uses_context
    assert_equal :ok, (Lucida::Rails::Configuration.new.build_client.capture("u", "e") || :ok)
    sent = []
    Lucida.client = Lucida::Client.new("k", flush_interval: 0, transport: lambda { |_u, b, _h|
      sent.concat(JSON.parse(b)["batch"])
      200
    })
    Lucida.with_context(distinct_id: "ctx") { Lucida::Rails.capture(nil, "hit", { "a" => 1 }) }
    Lucida::Rails.identify("u2", { "plan" => "pro" })
    Lucida::Rails.alias("u2", "anon")
    Lucida::Rails.group_identify("company", "acme", { "seats" => 1 })
    Lucida::Rails.flush
    assert_equal %w[hit $identify $create_alias $groupidentify], sent.map { |e| e["event"] }
    assert_equal "ctx", sent.first["distinct_id"]
  ensure
    Lucida.client = nil
  end

  def test_controller_context_layers_current_user
    base = Class.new do
      def self.around_action(name) = (@hook = name)
      def self.hook = @hook
    end
    base.include(Lucida::Rails::ControllerContext)
    assert_equal :lucida_user_context, base.hook
    ctrl = Class.new(base) { def current_user = Struct.new(:id).new(7) }.new
    seen = nil
    ctrl.send(:lucida_user_context) { seen = Lucida.current_context[:distinct_id] }
    assert_equal "7", seen
    anon = base.new
    seen = :unset
    anon.send(:lucida_user_context) { seen = Lucida.current_context[:distinct_id] }
    assert_nil seen
  end
end

begin
  require "rails"
  require "rails/generators"
  require "lucida/rails/railtie"
  require "generators/lucida/install/install_generator"
rescue LoadError
  RAILS_AVAILABLE = false
else
  RAILS_AVAILABLE = true
end

class RailsIntegrationTest < Minitest::Test
  def setup = skip("rails not installed") unless RAILS_AVAILABLE

  def test_railtie_defined
    assert_operator Lucida::Rails::Railtie, :<, ::Rails::Railtie
  end

  def test_generator_writes_initializer
    Dir.mktmpdir do |d|
      Lucida::Generators::InstallGenerator.start([], destination_root: d, shell: Thor::Base.shell.new.tap { |s| s.mute { nil } })
      body = File.read(File.join(d, "config/initializers/lucida.rb"))
      assert_includes body, "Lucida::Rails.configure"
      assert_includes body, "use_tracing_headers"
      assert_includes body, "current_user_method"
    end
  end
end
