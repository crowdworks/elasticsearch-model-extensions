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

          def dependent_custom_attributes
            @dependent_custom_attributes
          end

          def dependent_custom_attributes=(new_value)
            @dependent_custom_attributes = new_value
          end

          def each_dependent_attribute_for(changed_attributes)
            dependent_custom_attributes.each do |attributes, dependent_attributes|
              dependent_attributes.each do |dependent_attribute|
                attributes.each do |a|
                  yield dependent_attribute if changed_attributes.include? a
                end
              end
            end
          end

          def has_dependent_fields?(field)
            dependent_custom_attributes.any? do |from, to|
              from.include? field.to_s
            end
          end

          def has_association_named?(table_name)
            # TODO call `reflect_on_all_associations` through a proxy object
            base.reflect_on_all_associations.any? { |a| a.name == table_name }
          end
        end

        def self.included(base)
          base.extend ClassMethods

          dependency_tracker = DependencyTracker.new(base)

          base.class_eval do
            before_validation do
              dependency_tracker.each_dependent_attribute_for(changes) do |a|
                attribute_will_change! a
              end
            end
          end

          # TODO Assert that @__dependency_tracker__ is nil to prevent users from facing terrible bugs
          # trying to include this module multiple times

          base.instance_variable_set :@__dependency_tracker__, dependency_tracker
        end

        module ClassMethods
          # @return [DependencyTracker]
          def __dependency_tracker__
            @__dependency_tracker__
          end

          # @param [Hash[Array<String>, Array<String>]] dependencies
          def tracks_attributes_dependencies(dependencies)
            __dependency_tracker__.dependent_custom_attributes = dependencies.dup.freeze
          end
        end
      end
    end
  end
end
