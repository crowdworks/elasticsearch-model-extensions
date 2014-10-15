require 'elasticsearch/model/extensions/all'

RSpec.describe 'example' do
  before :all do
    ActiveRecord::Schema.define(:version => 1) do
      create_table :articles do |t|
        t.string :title
        t.datetime :created_at, :default => 'NOW()'
      end
    end

    class ::Article < ActiveRecord::Base
      include Elasticsearch::Model
      include Elasticsearch::Model::Callbacks
      include Elasticsearch::Model::Extensions::IndexOperations
      include Elasticsearch::Model::Extensions::BatchUpdating
      include Elasticsearch::Model::Extensions::PartialUpdating

      DEPENDENT_CUSTOM_ATTRIBUTES = {}

      include Elasticsearch::Model::Extensions::DependencyTracking

      settings index: {number_of_shards: 1, number_of_replicas: 0} do
        mapping do
          indexes :title, type: 'string', analyzer: 'snowball'
          indexes :created_at, type: 'date'
        end
      end
    end

    Article.delete_all
    Article.__elasticsearch__.create_index! force: true

    ::Article.create! title: 'Test'
    ::Article.create! title: 'Testing Coding'
    ::Article.create! title: 'Coding'

    Article.__elasticsearch__.refresh_index!
  end

  subject {
    ::Article.create(title: 'foo', created_at: Time.now)
  }

  it { is_expected.not_to be_nil }
end
