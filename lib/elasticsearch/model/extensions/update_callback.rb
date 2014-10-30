require_relative 'callback'

module Elasticsearch
  module Model
    module Extensions
      class UpdateCallback < Callback
        def after_commit(record)
          field_to_update = config.field_to_update
          records_to_update_documents = config.records_to_update_documents
          optionally_delayed = config.optionally_delayed
          only_if = config.only_if
          block = config.block

          record.instance_eval do
            return unless only_if.call(self) && index_update_required?

            target = records_to_update_documents.call(self)

            if target.respond_to? :each
              # `reload` required to ensure that the outer record is up-to-date with changes
              # when `self` is an instance of a `through` model.
              #
              # Imagine the case where we have an association containing:
              #
              #   `article has_many comments through article_comments`
              #
              # and:
              #
              #   `article_comments belongs_to article`
              #
              # Here, `article_comment.article` may contain outdated `comments` because `article_comment.article`
              # won't be notified with changes in `article_comments` thus won't reload `comments` automatically.
              target.map(&:reload).map(&optionally_delayed).each do |t|
                block.call(t, [*field_to_update])
              end
            else
              optionally_delayed.call(target.reload).partially_update_document(field_to_update)
            end
          end
        end
      end
    end
  end
end