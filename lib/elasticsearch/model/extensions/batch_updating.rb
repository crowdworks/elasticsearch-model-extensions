require_relative 'mapping_reflection'
require_relative 'batch_updating/batch_updater'

module Elasticsearch
  module Model
    module Extensions
      module BatchUpdating
        DEFAULT_BATCH_SIZE = 100

        def self.included(klass)
          klass.extend ClassMethods

          unless klass.respond_to? :with_indexed_tables_included
            class << klass
              def with_indexed_tables_included
                raise "#{self}.with_indexed_tables_included is not implemented."
              end
            end
          end

          unless klass.respond_to? :elasticsearch_hosts
            class << klass
              def elasticsearch_hosts
                raise "#{self}.elasticsearch_hosts is not implemented."
              end
            end
          end
        end

        module ClassMethods
          def __batch_updater__
            @__batch_updater__ ||= ::Elasticsearch::Model::Extensions::BatchUpdating::BatchUpdater.new(self)
          end

          def update_index_in_parallel(parallelism:, index: nil, type: nil, min: nil, max: nil, batch_size:DEFAULT_BATCH_SIZE)
            klass = self

            Parallel.each(__batch_updater__.split_ids_into(parallelism, min: min, max: max), in_processes: parallelism) do |id_range|
              __batch_updater__.reconnect!
              klass.for_indexing.update_index_for_ids_in_range id_range, index: index, type: type, batch_size: batch_size
            end

            klass.connection.reconnect!
          end

          def for_indexing
            for_batch_indexing
          end

          def for_batch_indexing
            with_indexed_tables_included.extending(::Elasticsearch::Model::Extensions::BatchUpdating::Association::Extension)
          end

          # @param [Fixnum] batch_size
          def update_index_in_batches(batch_size: DEFAULT_BATCH_SIZE, where: nil, index: nil, type: nil)
            records_in_scope = if where.nil?
                                 for_batch_indexing
                               else
                                 for_batch_indexing.where(where)
                               end

            records_in_scope.update_index_in_batches(batch_size: batch_size, index: index, type: type)
          end
        end

        module Association
          module Extension
            def update_index_in_chunks(num, index: index)
              klass.split_ids_into(num).map do |r|
                if block_given?
                  yield -> { update_index_for_ids_in_range(r, index: index) }
                else
                  update_index_for_ids_in_range(r, index: index)
                end
              end
            end

            def update_index_for_ids_from(from, to:, index: nil, type: nil, batch_size: DEFAULT_BATCH_SIZE)
              record_id = arel_table[:id]

              conditions = record_id.gteq(from).and(record_id.lteq(to))

              update_index_in_batches(batch_size: batch_size, index: index, type: type, conditions: conditions)
            end

            def update_index_for_ids_in_range(range, index: nil, type: nil, batch_size: DEFAULT_BATCH_SIZE)
              update_index_for_ids_from(range.first, to: range.last, type: type, index: index, batch_size: batch_size)
            end

            def update_index_in_batches(batch_size: DEFAULT_BATCH_SIZE, conditions:nil, index: nil, type: nil)
              find_in_batches(batch_size: batch_size, conditions: conditions) do |records|
                __batch_updater__.update_index_in_batch(records, index: index, type: type)
              end
            end
          end
        end
      end
    end
  end
end
