load 'setup/undefine.rb'

require 'elasticsearch/model/extensions/all'

ActiveRecord::Schema.define(:version => 1) do
  create_table :authors do |t|
    t.string :nickname
    t.datetime :created_at, :default => 'NOW()'
  end

  create_table :author_profiles do |t|
    t.integer :author_id
    t.string :description
    t.datetime :created_at, :default => 'NOW()'
  end

  create_table :books do |t|
    t.integer :author_id
    t.string :title
    t.datetime :created_at, :default => 'NOW()'
  end

  create_table :tags do |t|
    t.string :taggable_type
    t.integer :taggable_id
    t.string :body
    t.datetime :created_at, :default => 'NOW()'
    t.datetime :deleted_at, :default => 'NOW()'
  end
end

class Author < ActiveRecord::Base
  has_many :books
  has_one :profile, class_name: 'AuthorProfile'
  has_many :tags, as: :taggable

  accepts_nested_attributes_for :books
  accepts_nested_attributes_for :profile
  accepts_nested_attributes_for :tags

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating

  DEPENDENT_CUSTOM_ATTRIBUTES = {
    %w| books | => %w| num_books |,
    %w| tags | => %w| num_tags |
  }

  include Elasticsearch::Model::Extensions::DependencyTracking

  settings index: {number_of_shards: 1, number_of_replicas: 0} do
    mapping do
      indexes :nickname, type: 'string', analyzer: 'snowball', include_in_all: true
      indexes :created_at, type: 'date'
      indexes :books, type: 'object' do
        indexes :title, type: 'string', include_in_all: true
      end
      indexes :profile, type: 'object' do
        indexes :description, type: 'string', include_in_all: true
      end
      indexes :tags, type: 'object' do
        indexes :body, type: 'string', include_in_all: true
      end
      indexes :num_books, type: 'long'
      indexes :num_tags, type: 'long'
    end
  end

  def num_books
    books.count
  end

  def num_tags
    tags.count
  end

  # Required by AuthorProfile's `OuterDocumentUpdating`
  include Elasticsearch::Model::Extensions::MappingReflection
end

class ::AuthorProfile < ActiveRecord::Base
  belongs_to :author
end

class ::Book < ActiveRecord::Base
  belongs_to :author
  has_many :tags, as: :taggable

  accepts_nested_attributes_for :tags

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating
  include Elasticsearch::Model::Extensions::OuterDocumentUpdating

  DEPENDENT_CUSTOM_ATTRIBUTES = {
    %w| tags | => %w| num_tags |
  }

  include Elasticsearch::Model::Extensions::DependencyTracking

  settings index: {number_of_shards: 1, number_of_replicas: 0} do
    mapping do
      indexes :title, type: 'string', analyzer: 'snowball', include_in_all: true
      indexes :created_at, type: 'date'
      indexes :tags, type: 'object' do
        indexes :body, type: 'string', include_in_all: true
      end
      indexes :num_tags, type: 'long'
    end
  end

  def num_tags
    tags.count
  end

  # Required by Review's `OuterDocumentUpdating`
  include Elasticsearch::Model::Extensions::MappingReflection

  partially_updates_document_of ::Author, records_to_update_documents: -> book { Author.find(book.author_id) } do |t, changed_fields|
    t.partially_update_document(*changed_fields)
  end
end

class ::Tag < ActiveRecord::Base
  belongs_to :taggable, polymorphic: true

  default_scope { where(arel_table[:deleted_at].eq(nil)) }

  include Elasticsearch::Model
  include Elasticsearch::Model::Extensions::IndexOperations
  include Elasticsearch::Model::Extensions::BatchUpdating
  include Elasticsearch::Model::Extensions::PartialUpdating
  include Elasticsearch::Model::Extensions::OuterDocumentUpdating

  def assigned_to_author?
    taggable_type == 'Author'
  end

  def assigned_to_book?
    taggable_type == 'Book'
  end

  partially_updates_document_of ::Book, records_to_update_documents: -> tag { Book.find(tag.taggable_id) } do |t, changed_fields|
    t.partially_update_document(*changed_fields)
  end

  partially_updates_document_of ::Author, records_to_update_documents: -> tag { Author.find(tag.taggable_id) } do |t, changed_fields|
    t.partially_update_document(*changed_fields)
  end
end

Book.delete_all
Book.__elasticsearch__.create_index! force: true

Author.delete_all
Author.__elasticsearch__.create_index! force: true

Author.create! nickname: 'Mikoto',
               books_attributes: [
                 {title: 'Test', tags_attributes: [{body: 'testing'}]}
               ],
               tags_attributes: [
                 {body: 'testing'}
               ]

Author.create! nickname: 'Kuroko',
               books_attributes: [
                 {title: 'Code & Test', tags_attributes: [{body: 'testing'}, {body: 'coding'}]},
                 {title: 'Code', tags_attributes: [{body: 'coding'}]}
               ],
               tags_attributes: [
                 {body: 'testing'},
                 {body: 'coding'}
               ]

Book.__elasticsearch__.refresh_index!
Author.__elasticsearch__.refresh_index!
