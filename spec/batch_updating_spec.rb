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

  describe '#reconnect!' do
    subject {
      -> { Article.__batch_updater__.reconnect! }
    }

    it { is_expected.not_to raise_error }
  end

  context 'the index dropped' do
    before(:each) do
      Article.__elasticsearch__.create_index! force: true
      Article.__elasticsearch__.refresh_index!

      Article.class_eval do
        def self.with_indexed_tables_included
          includes(:comments)
        end
      end
    end

    shared_examples 'indexing all articles' do
      def number_of_articles_about_coding
        Article.search('Coding').records.size
      end

      specify {
        expect { subject; Article.__elasticsearch__.refresh_index! }.to change { number_of_articles_about_coding }.by(2)
      }
    end

    describe '.update_index_in_parallel' do
      subject {
        Article.update_index_in_parallel(parallelism: 1)
      }

      before(:each) do
        expect(Parallel).to receive(:each).with([0..3], in_processes: 1).and_yield(1..3).once
      end

      it_behaves_like 'indexing all articles'
      end

    describe '.update_index_in_batches' do
      subject {
        Article.update_index_in_batches
      }

      it_behaves_like 'indexing all articles'
    end

    describe 'Association/Extension' do
      describe '.update_index_for_ids_in_range' do
        subject {
          Article.for_indexing.update_index_for_ids_in_range(Article.minimum(:id)..Article.maximum(:id))
        }

        it_behaves_like 'indexing all articles'
      end

      describe '.update_index_in_batches' do
        subject {
          Article.for_indexing.update_index_in_batches
        }

        it_behaves_like 'indexing all articles'
      end
    end
  end
end
