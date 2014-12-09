module Elasticsearch
  module Model
    module Extensions
      module DependencyTracking
        class DependencyTracker
          def initialize(base)
            @base = base
          end

          def base
            @base
          end

          # @return [Hash<Array<String>, Array<String>>]
          def dependent_custom_attributes
            @dependent_custom_attributes
          end

          # @param [Hash<Array<String>, Array<String>>] new_value
          def dependent_custom_attributes=(new_value)
            @dependent_custom_attributes = new_value
          end

          # @param [Array<String>] changed_attributes
          def each_dependent_attribute_for(changed_attributes)
            dependent_custom_attributes.each do |attributes, dependent_attributes|
              dependent_attributes.each do |dependent_attribute|
                attributes.each do |a|
                  yield dependent_attribute if changed_attributes.include? a
                end
              end
            end
          end

          # @param [String|Symbol] field
          def has_dependent_fields?(field)
            dependent_custom_attributes.any? do |from, to|
              from.include? field.to_s
            end
          end

          # @param [Symbol] table_name
          def has_association_named?(table_name)
            # TODO call `reflect_on_all_associations` through a proxy object
            base.reflect_on_all_associations.any? { |a| a.name == table_name }
          end
        end

      end
    end
  end
end
