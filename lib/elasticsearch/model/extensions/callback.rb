require_relative 'configuration'

module Elasticsearch
  module Model
    module Extensions
      class Callback
        # @param [Configuration] config
        def initialize(config)
          @config = config
        end

        def config
          @config
        end
      end
    end
  end
end
