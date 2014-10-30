require 'elasticsearch/extensions/test/cluster'

Elasticsearch::Extensions::Test::Cluster.start(nodes:1)

ENV['TEST_CLUSTER_PORT'] = '9250'
