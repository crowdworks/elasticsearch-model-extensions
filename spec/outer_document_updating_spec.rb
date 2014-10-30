require 'elasticsearch/model/extensions/all'

RSpec.describe Elasticsearch::Model::Extensions::OuterDocumentUpdating do
  before(:each) do
    load 'setup/articles_with_comments.rb'
  end

  after :each do
    ActiveRecord::Schema.define(:version => 2) do
      drop_table :comments
      drop_table :articles
    end
  end

  context 'with a comment added' do
    def article
      ::Article.search('Comment1').records.first
    end

    before(:each) do
      article.comments.create(body: 'Comment2')

      Article.__elasticsearch__.refresh_index!
    end

    specify {
      expect(Article.search('Comment1').records.first).not_to be_nil
      expect(Article.search('Comment2').records.first).not_to be_nil
    }
  end
end
