require 'delayed_job'

module Elasticsearch
  module Model
    module Extensions
      module DelayedJob

        require 'delayed_job'

        class DocumentJob
          def initialize(params)
            record = params[:record]
            @active_record = params[:active_record] || record.class
            @id = params[:id] || record.id
            @run_only_if = params[:run_only_if]
          end

          def max_attempts
            10
          end

          def enqueue!
            Delayed::Job.enqueue self
          end

          protected

          def find_record_or_raise
            @active_record.find(@id)
          end

          def record
            begin
              find_record_or_raise
            rescue ActiveRecord::RecordNotFound => e
              Rails.logger.info "#{self.class.name}: #{e.to_s}"
              nil
            end
          end

          def if_enabled_try_with_record(&block)
            if @run_only_if.nil? || @run_only_if[0].send(@run_only_if[1])
              try_with_record(&block)
            end
          end

          def try_with_record
            record.tap do |r|
              yield r if r
            end
          end
        end

      end
    end
  end
end

