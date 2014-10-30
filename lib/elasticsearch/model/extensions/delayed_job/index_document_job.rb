require_relative 'document_job'

module Elasticsearch
  module Model
    module Extensions
      module DelayedJob

        class IndexDocumentJob < DocumentJob
          def initialize(params)
            super
          end

          def perform
            try_with_record do |record|
              record.__elasticsearch__.index_document
            end
          end
        end

      end
    end
  end
end
