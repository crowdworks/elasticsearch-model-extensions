module Elasticsearch
  module Model
    module Extensions
      class Configuration
        attr_reader :delayed

        def initialize(active_record_class, parent_class: parent_class, delayed:, only_if: -> r { true }, records_to_update_documents: nil, field_to_update: nil, block: nil)
          @delayed = @delayed

          @active_record_class = active_record_class
          @parent_class = parent_class
          @if = binding.local_variable_get(:only_if)
          @records_to_update_documents = records_to_update_documents
          @field_to_update = field_to_update
          @block = block
        end

        def to_hash
          @cached_hash ||= build_hash
        end

        def field_to_update
          to_hash[:field_to_update]
        end

        def only_if
          to_hash[:only_if]
        end

        def records_to_update_documents
          to_hash[:records_to_update_documents]
        end

        def optionally_delayed
          -> t { delayed ? t.delay : t }
        end

        def block
          to_hash[:block]
        end

        # TODO Document what is in the Array
        # @return [Array]
        def nested_object_fields
          @nested_object_fields
        end

        # @return [Boolean]
        def has_dependent_fields?
          @has_dependent_fields
        end

        # @param [ActiveRecord::Base] record the updated record we are unsure
        # whether it must be also updated in elasticsearch or not
        # @return [Boolean] true if we have to update the document for the record indexed in Elasticsearch
        def index_update_required?(record)
          previous_changes = record.previous_changes

          defined?(record.index_update_required?) && record.index_update_required? ||
            (previous_changes.keys & nested_object_fields).size > 0 ||
            (previous_changes.size > 0 && has_dependent_fields?)
        end

        private

        def build_hash
          child_class = @active_record_class

          field_to_update = @field_to_update || begin
            path = child_class.path_from(@parent_class)
            parent_to_child_path = path.map(&:name)

            # a has_a b has_a cという関係のとき、cが更新されたらaのフィールドbをupdateする必要がある。
            # そのとき、
            # 親aから子cへのパスが[:b, :c]だったら、bだけをupdateすればよいので
            parent_to_child_path.first
          end

          parent_to_child_path ||= [field_to_update]

          puts "#{child_class.name} updates #{@parent_class.name}'s #{field_to_update}"

          @nested_object_fields = @parent_class.__mapping_reflector__.nested_object_fields_for(parent_to_child_path).map(&:to_s)
          @has_dependent_fields = @parent_class.__dependency_tracker__.has_dependent_fields?(field_to_update) ||
            (path.first.destination.through_class == child_class && @parent_class.__dependency_tracker__.has_association_named?(field_to_update) && @parent_class.__mapping_reflector__.has_document_field_named?(field_to_update))

          custom_if = @if

          update_strategy_class = Elasticsearch::Model::Extensions::OuterDocumentUpdating.strategy_for child_class
          update_strategy = update_strategy_class.new(from: @parent_class, to: child_class)

          only_if, records_to_update_documents = update_strategy.apply

          # The default block used to trigger partial updating on the parent document.
          # Replace this by specifying `block` parameter to a configuration like `Configuration.new(block: BLOCK)`
          # when more fine-grained controls over it like feature-toggling, graceful-degradation are required.
          default_partial_updating_block = -> t, field_to_update {
            t.partially_update_document(field_to_update)
          }

          {
            field_to_update: field_to_update,
            records_to_update_documents: @records_to_update_documents || records_to_update_documents,
            only_if: -> r { custom_if.call(r) && only_if.call(r) },
            block: @block || default_partial_updating_block
          }
        end
      end
    end
  end
end
