require_relative 'callback'

module Elasticsearch
  module Model
    module Extensions
      class DestroyCallback < Callback
        def after_commit(record)
          field_to_update = config.field_to_update
          records_to_update_documents = config.records_to_update_documents
          optionally_delayed = config.optionally_delayed
          only_if = config.only_if

          record.instance_eval do
            return unless only_if.call(self)

            target = records_to_update_documents.call(self)

            if target.respond_to? :each
              target.map(&:reload).map(&optionally_delayed).each do |t|
                t.partially_update_document(field_to_update)
              end
            else
              optionally_delayed.call(target.reload).partially_update_document(field_to_update)
            end
          end
        end
      end
    end
  end
end
