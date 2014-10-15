RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.profile_examples = 10

  config.order = :random

  Kernel.srand config.seed

  config.before(:all) do
    require 'active_record'
    require 'logger'
    require 'elasticsearch/model'

    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ":memory:")
    logger = ::Logger.new(STDERR)
    logger.formatter = lambda { |s, d, p, m| "\e[2;36m#{m}\e[0m\n" }
    ActiveRecord::Base.logger = logger unless ENV['QUIET']

    ActiveRecord::LogSubscriber.colorize_logging = false
    ActiveRecord::Migration.verbose = false

    tracer = ::Logger.new(STDERR)
    tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }}\n" }

    Elasticsearch::Model.client = Elasticsearch::Client.new host: "localhost:#{(ENV['TEST_CLUSTER_PORT'] || 9250)}",
                                                            tracer: (ENV['QUIET'] ? nil : tracer)
  end
end
