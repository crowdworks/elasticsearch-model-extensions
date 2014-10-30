require 'active_record'
require 'logger'

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ":memory:")
logger = ::Logger.new(STDERR)
logger.formatter = lambda { |s, d, p, m| "\e[2;36m#{m}\e[0m\n" }
ActiveRecord::Base.logger = logger unless ENV['QUIET']

ActiveRecord::LogSubscriber.colorize_logging = false
ActiveRecord::Migration.verbose = false
