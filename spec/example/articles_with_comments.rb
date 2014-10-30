load 'setup/sqlite.rb'
load 'setup/elasticsearch/model.rb'
load 'setup/elasticsearch/start.rb'
load 'setup/articles_with_comments.rb'

at_exit do
  load 'setup/elasticsearch/stop.rb'
end
