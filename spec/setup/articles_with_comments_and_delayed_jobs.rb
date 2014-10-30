load 'setup/undefine.rb'

require 'elasticsearch/model/extensions/all'
require 'elasticsearch/model/extensions/delayed_job'

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

  create_table :delayed_jobs, :force => true do |table|
    table.integer  :priority, :default => 0
    table.integer  :attempts, :default => 0
    table.text     :handler
    table.text     :last_error
    table.datetime :run_at
    table.datetime :locked_at
    table.datetime :failed_at
    table.string   :locked_by
    table.string   :queue
    table.timestamps
  end
end

Delayed::Worker.delay_jobs = false

class ::Article < ActiveRecord::Base
  has_many :comments

  accepts_nested_attributes_for :comments

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating

  DEPENDENT_CUSTOM_ATTRIBUTES = {
    %w| comments | => %w| num_comments |
  }

  include Elasticsearch::Model::Extensions::DependencyTracking

  settings index: {number_of_shards: 1, number_of_replicas: 0} do
    mapping do
      indexes :title, type: 'string', analyzer: 'snowball'
      indexes :created_at, type: 'date'
      indexes :comments, type: 'object' do
        indexes :body, type: 'string', include_in_all: true
      end
      indexes :num_comments, type: 'long'
    end
  end

  def num_comments
    comments.count
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

  partially_updates_document_of ::Article, records_to_update_documents: -> comment { Article.find(comment.article_id) } do |t, changed_fields|
    Elasticsearch::Model::Extensions::DelayedJob::PartiallyUpdateDocumentJob.new(record: t, changes: changed_fields).enqueue!
  end
end

Article.delete_all
Article.__elasticsearch__.create_index! force: true

::Article.create! title: 'Test'
::Article.create! title: 'Testing Coding'
::Article.create! title: 'Coding', comments_attributes: [{ body: 'Comment1' }]

Article.__elasticsearch__.refresh_index!
