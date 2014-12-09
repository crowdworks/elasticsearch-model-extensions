module Elasticsearch
  module Model
    module Extensions
      module PartialUpdating
        class PartialUpdater
          def initialize(base)
            @base = base
          end

          def base
            @base
          end

          def build_as_json_options(klass:, props: )
            indexed_attributes = props.keys
            associations = klass.reflect_on_all_associations.select { |a| %i| has_one has_many belongs_to |.include? a.macro }
            association_names = associations.map(&:name)
            persisted_attributes = klass.attribute_names.map(&:intern)

            nested_attributes = indexed_attributes & association_names
            method_attributes = indexed_attributes - persisted_attributes - nested_attributes
            only_attributes = indexed_attributes - nested_attributes

            options = {
              root: false
            }

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

          def as_json_options
            @as_json_options ||= build_as_json_options(
              klass: base,
              props: base.mappings.to_hash[base.document_type.intern][:properties]
            )
          end

          def partial_as_json_options(field)
            as_json_options[:include][field]
          end

          def each_field_to_update_according_to_changed_fields(changed_fields)
            root_mapping_properties = base.mappings.to_hash[:"#{base.document_type}"][:properties]

            changed_fields.each do |changed_field|
              field_mapping = root_mapping_properties[:"#{changed_field}"]

              next unless field_mapping

              yield changed_field
            end

            base.__dependency_tracker__.each_dependent_attribute_for(changed_fields.map(&:to_s)) do |a|
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

          def build_partial_document_for_update_with_error_logging(record:, changed_attributes:, json_options: nil)
            begin
              build_partial_document_for_update(
                record: record,
                changed_attributes: changed_attributes,
                json_options: json_options
              )
            rescue => e
              if defined? ::Rails
                ::Rails.logger.error "Error in #build_partial_document_for_update_with_error_logging: #{e.message}\n#{e.backtrace.join("\n")}"
              else
                warn "Error in #build_partial_document_for_update_with_error_logging: #{e.message}\n#{e.backtrace.join("\n")}"
              end

              nil
            end
          end

          # @param [ActiveRecord::Base] record
          # @param [Array<Symbol>] changed_attributes
          # @param [Proc<Symbol, Hash>] json_options
          def build_partial_document_for_update(record:, changed_attributes:, json_options: nil)
            changes = {}

            json_options ||= -> field { partial_as_json_options(field) || {} }

            each_field_to_update_according_to_changed_fields(changed_attributes) do |field_to_update|
              options = json_options.call field_to_update

              json = record.__send__(:"#{field_to_update}").as_json(options)

              changes[field_to_update] = json
            end

            changes
          end

          # @param [Hash] doc
          def update_document(id:, doc:)
            base.__elasticsearch__.client.update(
              { index: base.index_name,
                type:  base.document_type,
                id:    id,
                body:  { doc: doc } }
            ) if doc.size > 0
          end

        end
      end
    end
  end
end
