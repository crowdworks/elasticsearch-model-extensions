require 'elasticsearch/model/extensions/all'

ActiveRecord::Schema.define(:version => 1) do
  create_table :articles do |t|
    t.string :title
    t.datetime :created_at, :default => 'NOW()'
  end

  create_table :comments do |t|
    t.integer :article_id
    t.string :body
    t.datetime :created_at, :default => 'NOW()'
  end
end

class ::Article < ActiveRecord::Base
  has_many :comments

  accepts_nested_attributes_for :comments

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating

  DEPENDENT_CUSTOM_ATTRIBUTES = {
  }

  include Elasticsearch::Model::Extensions::DependencyTracking

  settings index: {number_of_shards: 1, number_of_replicas: 0} do
    mapping do
      indexes :title, type: 'string', analyzer: 'snowball'
      indexes :created_at, type: 'date'
      indexes :comments, type: 'object' do
        indexes :body, type: 'string', include_in_all: true
      end
    end
  end

  # Required by Comment's `OuterDocumentUpdating`
  include Elasticsearch::Model::Extensions::MappingReflection
end

class ::Comment < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating
  include Elasticsearch::Model::Extensions::OuterDocumentUpdating

  partially_updates_document_of ::Article, records_to_update_documents: -> comment { Article.find(comment.article_id) }
end

Article.delete_all
Article.__elasticsearch__.create_index! force: true

::Article.create! title: 'Test'
::Article.create! title: 'Testing Coding'
::Article.create! title: 'Coding', comments_attributes: [{ body: 'Comment1' }]

Article.__elasticsearch__.refresh_index!
