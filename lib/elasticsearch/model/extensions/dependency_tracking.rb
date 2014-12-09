require_relative 'dependency_tracking/dependency_tracker'

module Elasticsearch
  module Model
    module Extensions
      module DependencyTracking
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
