require_relative 'mapping_node'

module Elasticsearch
  module Model
    module Extensions
      module AssociationPathFinding
        class AssociationPathFinder
          def find_path(from:, to:)
            MappingNode.
              from_class(from).
              breadth_first_search { |e| e.destination.relates_to_class?(to) }.
              first
          end
        end

      end
    end
  end
end
