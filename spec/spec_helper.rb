# frozen_string_literal: true

require "tmpdir"
require "fileutils"

PROJECT_ROOT = File.expand_path("..", __dir__)

require_relative "../lib/livebarn_tools"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
