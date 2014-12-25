require 'elasticsearch/model/extensions/all'

require 'parallel'

RSpec.describe Elasticsearch::Model::Extensions::BatchUpdating do
  before(:each) do
    load 'setup/articles_with_comments.rb'
  end

  after(:each) do
    ActiveRecord::Schema.define(:version => 2) do
      drop_table :comments
      drop_table :articles
    end
  end

  subject {
    Article
  }

  describe '.with_indexed_tables_included' do
    subject {
      Article.with_indexed_tables_included
    }

    context 'without a `with_indexed_tables_included` implementation' do
      specify {
        expect { subject }.to raise_error
      }
    end

    context 'with a `with_indexed_tables_included` implementation' do
      before(:each) do
        Article.class_eval do
          def self.with_indexed_tables_included
            includes(:comments)
          end
        end
      end

      specify {
        expect { subject }.to_not raise_error
      }
    end
  end

  describe '.elasticsearch_hosts' do
    subject {
      Article.elasticsearch_hosts
    }

    context 'without a `elasticsearch_hosts` implementation' do
      specify {
        expect { subject }.to raise_error
      }
    end

    context 'with a `elasticsearch_hosts` implementation' do
      before(:each) do
        Article.class_eval do
          def self.elasticsearch_hosts
            'http://localhost:9250'
          end
        end
      end

      specify {
        expect { subject }.to_not raise_error
      }
    end
  end

  context 'the index dropped' do
    before(:each) do
      Article.__elasticsearch__.create_index! force: true
      Article.__elasticsearch__.refresh_index!

      Article.class_eval do
        def self.elasticsearch_hosts
          listened_port = (ENV['TEST_CLUSTER_PORT'] || 9250)
          "http://localhost:#{listened_port}/"
        end

        def self.with_indexed_tables_included
          includes(:comments)
        end
      end
    end

    def number_of_articles_about_coding
      Article.search('Coding').records.size
    end

    describe '.update_index_in_parallel' do
      subject {
        Article.update_index_in_parallel(parallelism: 2)
        Article.__elasticsearch__.refresh_index!
      }

      specify {
        expect { subject }.to change { number_of_articles_about_coding }.by(2)
      }
    end
  end
end
