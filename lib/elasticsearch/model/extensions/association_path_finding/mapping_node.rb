require_relative 'shortest_path'

module Elasticsearch
  module Model
    module Extensions
      module AssociationPathFinding
        class MappingNode < ShortestPath::Node
          def self.from_class(klass)
            name = klass.document_type.intern

            new(klass: klass, name: name, mapping: klass.mapping.to_hash[name])
          end

          def initialize(klass:, name:, mapping:, through_class:nil)
            @klass = klass
            @name = name
            @mapping = mapping
            @through_class = through_class
          end

          def name
            @name
          end

          def relates_to_class?(klass)
            @klass == klass || @through_class == klass
          end

          def klass
            @klass
          end

          def through_class
            @through_class
          end

          def each(&block)
            associations = @klass.reflect_on_all_associations

            props = @mapping[:properties]
            fields = props.keys

            edges = fields.map { |f|
              a = associations.find { |a| a.name == f }

              if a && a.options[:polymorphic] != true
                through_class = if a.options[:through]
                                  a.options[:through].to_s.classify.constantize
                                end

                dest = MappingNode.new(klass: a.class_name.constantize, name: f.to_s.pluralize.intern, mapping: props[f], through_class: through_class)

                edge_class.new(name: f, destination: dest)
              end
            }.reject(&:nil?)

            if block.nil?
              edges
            else
              edges.each(&block)
            end
          end

        end
      end
    end
  end
end
