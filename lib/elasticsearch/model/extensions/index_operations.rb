module Elasticsearch
  module Model
    module Extensions
      module IndexOperations
        def self.included(klass)
          klass.extend ClassMethods
        end

        module ClassMethods
          def create_index(name:, force:true)
            klass = self

            client = __elasticsearch__.client

            indices = client.indices

            if indices.exists(index: name) && force
              indices.delete index: name
            end

            indices.create index: name, body: { settings: klass.settings.to_hash, mappings: klass.mappings.to_hash }
          end

          def delete_index(name:)
            client = __elasticsearch__.client

            indices = client.indices

            indices.delete index: name
          end

          def delete_alias(name: nil)
            name ||= index_name

            client = __elasticsearch__.client

            indices = client.indices

            indices_aliased = indices.get_alias(name: name).keys

            indices_aliased.each do |index|
              indices.delete name: name, index: index
            end
          end

          def prepare_alias(name:, force: true)
            client = __elasticsearch__.client

            indices = client.indices

            if indices.exists(index: name) && force
              indices.delete index: name
            end

            unless indices.exists_alias(name: name)
              aliased_index_name = "#{index_name}_#{Time.now.to_i}"

              create_index(name: aliased_index_name, force: force)

              indices.put_alias index: aliased_index_name, name: name
            end
          end

          def replace_index_for_alias(name:, to:)
            client = __elasticsearch__.client

            indices = client.indices

            if indices.exists_alias name: name
              old_index_name = indices.get_alias(name: name).keys.first

              indices.update_aliases body: {
                actions: [
                  { remove: { index: old_index_name, alias: name } },
                  { add: { index: to, alias: name } }
                ]
              }
            else
              indices.put_alias index: to, name: name
            end
          end
        end
      end
    end
  end
end
