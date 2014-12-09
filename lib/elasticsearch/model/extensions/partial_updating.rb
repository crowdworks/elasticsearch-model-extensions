require_relative 'partial_updating/partial_updater'

module Elasticsearch
  module Model
    module Extensions
      module PartialUpdating
        def self.included(klass)
          klass.extend ClassMethods

          klass.instance_variable_set :@__partial_updater__, PartialUpdater.new(klass)
        end

        def as_indexed_json(options={})
          as_json(options.merge(self.class.__partial_updater__.as_json_options))
        end

        def partially_update_document(*changed_attributes)
          if changed_attributes.empty?
            __elasticsearch__.index_document
          else
            partial_updater = self.class.__partial_updater__

            partial_document = partial_updater.build_partial_document_for_update_with_error_logging(
              record: self,
              changed_attributes: changed_attributes
            )

            if partial_document
              partial_updater.update_document(id: self.id, doc: partial_document)
            end
          end

          true
        end

        module ClassMethods
          def __partial_updater__
            @__partial_updater__
          end
        end

        module Callbacks
          def self.included(base)
            base.class_eval do
              after_commit lambda { __elasticsearch__.index_document  },  on: :create
              after_commit lambda { partially_update_document(*previous_changes.keys.map(&:intern)) },  on: :update, if: -> { previous_changes.size != 0 }
              after_commit lambda { __elasticsearch__.delete_document },  on: :destroy
            end
          end
        end
      end
    end
  end
end
