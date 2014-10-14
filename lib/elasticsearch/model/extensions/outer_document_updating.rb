require_relative 'mapping_node'
require_relative 'update_callback'
require_relative 'destroy_callback'

module Elasticsearch
  module Model
    module Extensions
      module OuterDocumentUpdating
        def self.included(klass)
          klass.extend ClassMethods
        end

        def index_update_required?
          (previous_changes.keys & self.class.nested_object_fields).size > 0 ||
            (previous_changes.size > 0 && self.class.has_dependent_fields?)
        end

        class Update
          def initialize(from:, to:)
            @parent_class = from
            @child_class = to
          end

          class Default < Update
            def self.applicable_to?(klass)
              true
            end

            def apply
              parent_class = @parent_class
              child_class = @child_class

              only_if = -> r { true }

              puts "Parent: #{@parent_class.name}"
              puts "Child: #{@child_class.name}"

              # 子cから親aへのパスが[:b, :a]のようなパスだったら、c.b.aのようにaを辿れるはずなので
              records_to_update_documents = begin
                child_to_parent_path = Elasticsearch::Model::Extensions::OuterDocumentUpdating::ClassMethods::AssociationTraversal.shortest_path(from: child_class, to: parent_class)

                -> updated_record { child_to_parent_path.inject(updated_record) { |d, parent_association| d.send parent_association } }
              end

              [only_if, records_to_update_documents]
            end
          end

          # Configures callbacks to update the index of the model associated through a polymorphic association
          # @see http://guides.rubyonrails.org/association_basics.html#polymorphic-associations
          class ThroughPolymorphicAssociation < Update
            def self.applicable_to?(klass)
              !! polymorphic_assoc_for(klass)
            end

            def self.polymorphic_assoc_for(klass)
              klass.reflect_on_all_associations.find { |a|
                a.macro == :belongs_to && a.options[:polymorphic]
              }
            end

            def apply
              parent_class = @parent_class
              child_class = @child_class

              polymorphic_assoc = self.class.polymorphic_assoc_for(child_class)
              polymorphic_assoc_name = polymorphic_assoc.name

              parent_type_attribute_name = :"#{polymorphic_assoc_name}_type"
              parent_id_attribute_name = :"#{polymorphic_assoc_name}_id"

              only_if = -> updated_record {
                updated_record.send(parent_type_attribute_name) == parent_class.name
              }

              records_to_update_documents = -> updated_record {
                parent_class.where(id: updated_record.send(parent_id_attribute_name))
              }

              [only_if, records_to_update_documents]
            end
          end
        end

        STRATEGIES = [Update::ThroughPolymorphicAssociation, Update::Default]

        def self.strategy_for(klass)
          STRATEGIES.find { |s| s.applicable_to? klass }
        end

        module ClassMethods
          def nested_object_fields
            @nested_object_fields
          end

          def has_dependent_fields?
            @has_dependent_fields
          end

          def path_from(from)
            Elasticsearch::Model::Extensions::MappingNode.
              from_class(from).
              breadth_first_search { |e| e.destination.relates_to_class?(self) }.
              first
          end

          def initialize_active_record!(active_record_class, parent_class: parent_class, delayed:, if: -> r { true }, records_to_update_documents: nil)
            config = Elasticsearch::Model::Extensions::Configuration.new(active_record_class, parent_class: parent_class, delayed: delayed, if: binding.local_variable_get(:if), records_to_update_documents: records_to_update_documents)

            active_record_class.after_commit Elasticsearch::Model::Extensions::UpdateCallback.new(config)
            active_record_class.after_commit Elasticsearch::Model::Extensions::DestroyCallback.new(config), on: :destroy
          end

          def partially_updates_document_of(parent_class, delayed:, if: -> r { true }, records_to_update_documents: nil)
            initialize_active_record!(
              self,
              parent_class: parent_class,
              delayed: delayed,
              if: binding.local_variable_get(:if),
              records_to_update_documents: records_to_update_documents
            )
          end

          module AssociationTraversal
            class << self
              def shortest_path(from:, to:, visited_classes: nil)
                visited_classes ||= []
                current_class = from
                destination_class = to

                paths = []

                current_class.reflect_on_all_associations.each do |association_found|

                  next if association_found.options[:polymorphic]

                  key = association_found.name

                  begin
                    klass = association_found.class_name.constantize
                  rescue => e
                    warn "#{e.message} while reflecting #{current_class.name}\##{key}\n#{e.backtrace[0...1].join("\n")}"
                    next
                  end

                  next if visited_classes.include? association_found.class_name

                  if klass == destination_class
                    return [key]
                  else
                    suffix_found = shortest_path(
                      from: klass,
                      to: destination_class,
                      visited_classes: visited_classes.append(association_found.class_name)
                    )

                    if suffix_found
                      paths << [key] + suffix_found
                    end
                  end
                end

                if paths.empty?
                  nil
                else
                  paths.min_by { |path| path.size }
                end
              end
            end
          end
        end
      end
    end
  end
end
