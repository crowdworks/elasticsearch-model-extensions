module Elasticsearch
  module Model
    module Extensions
      module DependencyTracking
        def self.included(base)
          base.extend ClassMethods

          base.class_eval do
            before_validation do
              self.class.each_dependent_attribute_for(changes) do |a|
                attribute_will_change! a
              end
            end
          end
        end

        # TODO Avoid adding singleton methods to classes
        module ClassMethods
          def tracks_attributes_dependencies(dependencies)
            const_set 'DEPENDENT_CUSTOM_ATTRIBUTES', dependencies.dup.freeze
          end

          def each_dependent_attribute_for(changed_attributes)
            const_get('DEPENDENT_CUSTOM_ATTRIBUTES').each do |attributes, dependent_attributes|
              dependent_attributes.each do |dependent_attribute|
                attributes.each do |a|
                  yield dependent_attribute if changed_attributes.include? a
                end
              end
            end
          end

          def has_dependent_fields?(field)
            const_get('DEPENDENT_CUSTOM_ATTRIBUTES').any? do |from, to|
              from.include? field.to_s
            end
          end

          def has_association_named?(table_name)
            reflect_on_all_associations.any? { |a| a.name == table_name }
          end
        end
      end
    end
  end
end
