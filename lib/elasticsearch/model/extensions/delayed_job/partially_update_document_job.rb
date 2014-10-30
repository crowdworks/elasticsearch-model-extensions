require_relative 'document_job'

module Elasticsearch
  module Model
    module Extensions
      module DelayedJob

        class PartiallyUpdateDocumentJob < DocumentJob
          def initialize(params)
            super(record: params[:record])
            @changes = params[:changes]
          end

          def perform
            try_with_record do |record|
              record.partially_update_document(*@changes)
            end
          end
        end

      end
    end
  end
end
