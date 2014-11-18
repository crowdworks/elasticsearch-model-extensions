require_relative 'callback'

module Elasticsearch
  module Model
    module Extensions
      class DestroyCallback < Callback
        def after_commit(record)
          with_error_logging do
            records_to_update_documents = config.records_to_update_documents
            only_if = config.only_if
            callback = self

            record.instance_eval do
              return unless only_if.call(self)

              target = records_to_update_documents.call(self)

              if target.respond_to? :each
                callback.update_for_records(*target)
              else
                callback.update_for_records(target)
              end
            end
          end
        end
      end
    end
  end
end
