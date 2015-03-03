require 'elasticsearch/extensions/test/cluster'

port_to_listen = ENV['TEST_CLUSTER_PORT'] || '9250'

Elasticsearch::Extensions::Test::Cluster.start(
  nodes:1,
  port: port_to_listen.to_i,
  es_params: '-D es.discovery.zen.ping.multicast.enabled=false'
)
