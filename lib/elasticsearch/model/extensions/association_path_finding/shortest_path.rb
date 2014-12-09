module Elasticsearch
  module Model
    module Extensions
      module AssociationPathFinding
        class ShortestPath
          MAX_DEPTH = 5

          class Node
            include Enumerable

            def each(&block)
              raise "A required method #{self.class}#each is not implemented."
            end

            def name
              raise "A required method #{self.class}#name is not implemented."
            end

            def each_with_name(&block)
              iterator = each.lazy.map do |edge|
                [edge, edge.name]
              end

              if block.nil?
                iterator
              else
                iterator.each(&block)
              end
            end

            def hash
              name.hash
            end

            def eql?(other)
              self.class == other.class && (name.eql? other.name)
            end

            def edge_class
              ShortestPath::Edge
            end

            def breadth_first_search(&block)
              ShortestPath.breadth_first_search self, &block
            end
          end

          class Edge
            def initialize(name:, destination:)
              @name = name
              @destination = destination
            end

            def name
              @name
            end

            def destination
              @destination
            end
          end

          module ClassMethods
            def breadth_first_search(node, &block)
              original_paths = node.each.map { |e| [e] }
              paths = original_paths

              depth = 0

              loop {
                a = paths.select { |p|
                  if block.call(p.last)
                    p
                  end
                }

                return a if a.size != 0
                raise RuntimeError, 'Maximum depth exceeded while calculating the shortest path' if depth >= Elasticsearch::Model::Extensions::ShortestPath::MAX_DEPTH

                paths = paths.flat_map { |p|
                  p.last.destination.each.map { |e|
                    p + [e]
                  }
                }

                depth += 1
              }
            end

            def depth_first_search(node, &block)
              node.each.select do |edge|
                if block.call(edge)
                  [[edge]]
                else
                  depth_first_search(edge.destination, &block).map do |path|
                    [edge] + path
                  end
                end
              end
            end
          end

          extend ClassMethods
        end
      end
    end
  end
end
