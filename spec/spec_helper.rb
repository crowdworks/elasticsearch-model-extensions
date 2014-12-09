require 'coveralls'
Coveralls.wear!

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

  config.before :all do
    load 'setup/elasticsearch/start.rb'
    load 'setup/elasticsearch/model.rb'
  end

  config.after :all do
    load 'setup/elasticsearch/stop.rb'
  end

  config.before :suite do
    require 'setup/sqlite.rb'

    require 'database_cleaner'

    # https://github.com/DatabaseCleaner/database_cleaner#additional-activerecord-options-for-truncation
    DatabaseCleaner.clean_with :deletion, cache_tables: false
    DatabaseCleaner.strategy = :deletion
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.before(:each) do |s|
    md = s.metadata
    x = md[:example_group]
    STDERR.puts "==>>> #{x[:file_path]}:#{x[:line_number]} #{md[:description_args]}"
  end
end
