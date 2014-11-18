require_relative 'configuration'

module Elasticsearch
  module Model
    module Extensions
      class Callback
        # @param [Configuration] config
        def initialize(config)
          @config = config
        end

        def config
          @config
        end

        def with_error_logging
          begin
            yield
          rescue => e
            log "An error occured while calling Elasticsearch::Model::Extensions::#{self.class.name}#after_commit"
            log e.message
            log e.backtrace.join("\n")
          end

          true
        end

        def update_for_records(*records)
          field_to_update = config.field_to_update
          optionally_delayed = config.optionally_delayed
          block = config.block

          records.map(&:reload).map(&optionally_delayed).each do |t|
            log "Indexing #{t.class} id=#{t.id} fields=#{[*field_to_update].join(', ')}"
            block.call(t, [*field_to_update])
          end
        end

        def log(message)
          if defined?(::Rails.logger.warn)
            ::Rails.logger.warn message
          else
            warn message
          end
        end
      end
    end
  end
end
