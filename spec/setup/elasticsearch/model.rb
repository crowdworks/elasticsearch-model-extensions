require 'elasticsearch/model'

tracer = ::Logger.new(STDERR)
tracer.formatter = lambda { |s, d, p, m| "#{m.gsub(/^.*$/) { |n| '   ' + n }}\n" }

listened_port = (ENV['TEST_CLUSTER_PORT'] || 9250)

tracer.info "Connecting to the Elasticsearch listening for the port: #{listened_port}"

Elasticsearch::Model.client = Elasticsearch::Client.new host: "localhost:#{listened_port}",
                                                        tracer: (ENV['QUIET'] ? nil : tracer)
