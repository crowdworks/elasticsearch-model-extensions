module Elasticsearch
  module Model
    module Extensions
      module PartialUpdating
        def self.included(klass)
          klass.extend ClassMethods
        end

        def self.build_as_json_options(klass:, props: )
          indexed_attributes = props.keys
          associations = klass.reflect_on_all_associations.select { |a| %i| has_one has_many belongs_to |.include? a.macro }
          association_names = associations.map(&:name)
          persisted_attributes = klass.attribute_names.map(&:intern)

          nested_attributes = indexed_attributes & association_names
          method_attributes = indexed_attributes - persisted_attributes - nested_attributes
          only_attributes = indexed_attributes - nested_attributes

          options = {}

          if only_attributes.size > 1
            options[:only] = only_attributes
          elsif only_attributes.size == 1
            options[:only] = only_attributes.first
          end

          if method_attributes.size > 1
            options[:methods] = method_attributes
          elsif method_attributes.size == 1
            options[:methods] = method_attributes.first
          end

          nested_attributes.each do |n|
            a = associations.find { |a| a.name == n.intern }
            nested_klass = a.class_name.constantize
            nested_prop = props[n]
            if nested_prop.present?
              options[:include] ||= {}
              options[:include][n] = build_as_json_options(
                klass: nested_klass,
                props: nested_prop[:properties]
              )
            end
          end

          options
        end

        def as_indexed_json(options={})
          as_json(options.merge(self.class.as_json_options))
        end

        # @param [Array<Symbol>] changed_attributes
        # @param [Proc<Symbol, Hash>] json_options
        def build_partial_document_for_update(*changed_attributes, json_options: nil)
          changes = {}

          json_options ||= -> field { self.class.partial_as_json_options(field) || {} }

          self.class.each_field_to_update_according_to_changed_fields(changed_attributes) do |field_to_update|
            options = json_options.call field_to_update

            json = __send__(:"#{field_to_update}").as_json(options)

            changes[field_to_update] = json
          end

          changes
        end

        def partially_update_document(*changed_attributes)
          if changed_attributes.empty?
            __elasticsearch__.index_document
          else
            begin
              partial_document = build_partial_document_for_update(*changed_attributes)
            rescue => e
              Rails.logger.error "Error in #partially_update_document: #{e.message}\n#{e.backtrace.join("\n")}"
            end

            update_document(partial_document)
          end
        end

        # @param [Hash] partial_document
        def update_document(partial_document)
          klass = self.class

          __elasticsearch__.client.update(
            { index: klass.index_name,
              type:  klass.document_type,
              id:    self.id,
              body:  { doc: partial_document } }
          ) if partial_document.size > 0
        end

        module ClassMethods
          def as_json_options
            @as_json_options ||= Elasticsearch::Model::Extensions::PartialUpdating.build_as_json_options(
              klass: self,
              props: self.mappings.to_hash[self.document_type.intern][:properties]
            )
          end

          def partial_as_json_options(field)
            as_json_options[:include][field]
          end

          def each_field_to_update_according_to_changed_fields(changed_fields)
            root_mapping_properties = mappings.to_hash[:"#{document_type}"][:properties]

            changed_fields.each do |changed_field|
              field_mapping = root_mapping_properties[:"#{changed_field}"]

              next unless field_mapping

              yield changed_field
            end

            each_dependent_attribute_for(changed_fields.map(&:to_s)) do |a|
              a_sym = a.intern

              yield a_sym
            end
          end

          def fields_to_update_according_to_changed_fields(changed_fields)
            fields = []
            each_field_to_update_according_to_changed_fields changed_fields do |field_to_update|
              fields << field_to_update
            end
            fields
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
