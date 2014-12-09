require_relative 'mapping_reflection/mapping_reflector'

module Elasticsearch
  module Model
    module Extensions
      module MappingReflection
        def self.included(base)
          base.extend ClassMethods

          base.instance_variable_set :@__mapping_reflector__, MappingReflector.new(base)
        end

        module ClassMethods
          def __mapping_reflector__
            @__mapping_reflector__
          end
        end

      end
    end
  end
end
