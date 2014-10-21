module Elasticsearch
  module Model
    module Extensions
      class Configuration
        attr_reader :delayed

        def initialize(active_record_class, parent_class: parent_class, delayed:, only_if: -> r { true }, records_to_update_documents: nil, field_to_update: nil)
          @delayed = @delayed

          @active_record_class = active_record_class
          @parent_class = parent_class
          @if = binding.local_variable_get(:only_if)
          @records_to_update_documents = records_to_update_documents
          @field_to_update = field_to_update
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

        private

        def build_hash
          child_class = @active_record_class

          field_to_update = -> {
            path = child_class.path_from(@parent_class)
            parent_to_child_path = path.map(&:name)

            # a has_a b has_a cという関係のとき、cが更新されたらaのフィールドbをupdateする必要がある。
            # そのとき、
            # 親aから子cへのパスが[:b, :c]だったら、bだけをupdateすればよいので
            parent_to_child_path.first
          }.call || @field_to_update

          puts "#{child_class.name} updates #{@parent_class.name}'s #{field_to_update}"

          # TODO 勝手にインスタンスの状態を書き換えていて、相当いまいち。インスタンス外に出す。
          child_class.instance_variable_set :@nested_object_fields, @parent_class.nested_object_fields_for(parent_to_child_path).map(&:to_s)
          child_class.instance_variable_set :@has_dependent_fields, @parent_class.has_dependent_fields?(field_to_update) ||
            (path.first.destination.through_class == child_class && @parent_class.has_association_named?(field_to_update) && @parent_class.has_document_field_named?(field_to_update))

          custom_if = @if

          update_strategy_class = Elasticsearch::Model::Extensions::OuterDocumentUpdating.strategy_for child_class
          update_strategy = update_strategy_class.new(from: @parent_class, to: child_class)

          only_if, records_to_update_documents = update_strategy.apply

          {
            field_to_update: field_to_update,
            records_to_update_documents: @records_to_update_documents || records_to_update_documents,
            only_if: -> r { custom_if.call(r) && only_if.call(r) }
          }
        end
      end
    end
  end
end
