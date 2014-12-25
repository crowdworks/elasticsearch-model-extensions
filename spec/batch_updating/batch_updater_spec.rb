require 'elasticsearch/model/extensions/all'

RSpec.describe Elasticsearch::Model::Extensions::BatchUpdating::BatchUpdater do
  before(:each) do
    load 'setup/articles_with_comments.rb'
  end

  after :each do
    ActiveRecord::Schema.define(:version => 2) do
      drop_table :comments
      drop_table :articles
    end
  end

  let(:batch_updater) {
    Article.__batch_updater__
  }

  describe '#split_ids_into' do
    subject {
      batch_updater.split_ids_into(2, min: 0, max: 3)
    }

    specify {
      expect(subject).to eq([0..1, 2..3])
    }
  end

  context 'the index dropped' do
    before(:each) do
      Article.__elasticsearch__.create_index! force: true
      Article.__elasticsearch__.refresh_index!
    end

    def number_of_articles_about_coding
      Article.search('Coding').records.size
    end

    describe '.update_index_in_parallel' do
      subject {
        batch_updater.update_index_in_batch(Article.all.to_ary)
        Article.__elasticsearch__.refresh_index!
      }

      specify {
        expect { subject }.to change { number_of_articles_about_coding }.by(2)
      }
    end
  end
end
