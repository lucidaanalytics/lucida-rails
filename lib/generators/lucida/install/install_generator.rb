# frozen_string_literal: true

require "rails/generators"

module Lucida
  module Generators
    # rails g lucida:install
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Creates config/initializers/lucida.rb"

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/lucida.rb"
      end
    end
  end
end
