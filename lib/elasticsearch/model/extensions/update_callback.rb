require_relative 'callback'

module Elasticsearch
  module Model
    module Extensions
      class UpdateCallback < Callback
        def after_commit(record)
          with_error_logging do
            records_to_update_documents = config.records_to_update_documents
            only_if = config.only_if
            callback = self
            _config = config

            record.instance_eval do
              return unless only_if.call(self) && _config.index_update_required?(self)

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
                callback.update_for_records(*target)
              else
                callback.update_for_records(target)
              end
            end
          end
        end
      end
    end
  end
end