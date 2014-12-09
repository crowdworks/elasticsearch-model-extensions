module Elasticsearch
  module Model
    module Extensions
      module MappingReflection
        class MappingReflector
          # @param [Class] base A class extending ActiveRecord::Base
          def initialize(base)
            @base = base
          end

          def base
            @base
          end

          # @param [Class] destination_class
          def path_in_mapping_to_class(destination_class, current_properties: nil, current_class: nil, visited_classes: nil)
            current_properties ||= default_root_properties
            visited_classes ||= []
            current_class ||= self

            # Recurse only on associations
            current_properties.keys.each do |key|
              association_found = current_class.reflect_on_all_associations.find { |a| a.name == key }

              next unless association_found
              next if visited_classes.include? association_found.klass

              if association_found.klass == destination_class
                return [key]
              else
                suffix_found = path_in_mapping_to_class(
                  destination_class,
                  current_properties: current_properties[key][:properties],
                  current_class: association_found.klass,
                  visited_classes: visited_classes.dup.append(association_found.klass)
                )

                if suffix_found
                  return [key] + suffix_found
                end
              end
            end

            nil
          end

          # @param [Symbol] nested_object_name
          # @return [Array<Symbol>]
          def path_in_mapping_to(nested_object_name, root_properties: nil)
            root_properties ||= default_root_properties

            keys = root_properties.keys

            keys.each do |key|
              if key == nested_object_name
                return [key]
              end

              next if root_properties[key][:type] != 'object'

              suffix = path_in_mapping_to(nested_object_name, root_properties: root_properties[key][:properties])

              if suffix.include? nested_object_name
                return [key] + suffix
              end
            end
            []
          end

          def has_document_field_named?(field_name)
            !! document_field_named(field_name)
          end

          # @param [Array<Symbol>] path
          def nested_object_fields_for(path, root_properties: nil)
            root_properties ||= default_root_properties

            keys = root_properties.keys

            suffix, *postfix = path

            return root_properties.keys if suffix.nil?

            keys.each do |key|
              if key == suffix
                result = nested_object_fields_for(postfix, root_properties: root_properties[key][:properties])
                return result if result
              end
            end
          end

          protected

          def default_root_properties
            base.mappings.to_hash[:"#{base.document_type}"][:properties]
          end

          def document_field_named(field_name)
            root_properties ||= default_root_properties
            root_properties[field_name]
          end
        end

      end
    end
  end
end
