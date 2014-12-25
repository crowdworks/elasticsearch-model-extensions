module Elasticsearch
  module Model
    module Extensions
      module BatchUpdating
        class BatchUpdater
          def initialize(klass)
            @klass = klass
          end

          def klass
            @klass
          end

          def reconnect!
            klass.connection.reconnect!
            klass.__elasticsearch__.client = Elasticsearch::Client.new(host: klass.elasticsearch_hosts)
          end

          # @param [Array] records
          def update_index_in_batch(records, index: nil, type: nil, client: nil)
            client ||= klass.__elasticsearch__.client
            index ||= klass.index_name
            type ||= klass.document_type

            if records.size > 1
              response = client.bulk \
                             index:   index,
                             type:    type,
                             body:    records.map { |r| { index: { _id: r.id, data: r.as_indexed_json } } }

              one_or_more_errors_occurred = response["errors"]

              if one_or_more_errors_occurred
                if defined? ::Rails
                  ::Rails.logger.warn "One or more error(s) occurred while updating the index #{records} for the type #{type}\n#{JSON.pretty_generate(response)}"
                else
                  warn "One or more error(s) occurred while updating the index #{records} for the type #{type}\n#{JSON.pretty_generate(response)}"
                end
              end
            else
              records.each do |r|
                client.index index: index, type: type, id: r.id, body: r.as_indexed_json
              end
            end
          end

          def split_ids_into(chunk_num, min:nil, max:nil)
            min ||= klass.minimum(:id)
            max ||= klass.maximum(:id)
            chunk_num.times.inject([]) do |r,i|
              chunk_size = ((max-min+1)/chunk_num.to_f).ceil
              first = chunk_size * i

              last = if i == chunk_num - 1
                       max
                     else
                       chunk_size * (i + 1) - 1
                     end

              r << (first..last)
            end
          end

        end
      end
    end
  end
end
