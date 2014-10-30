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

  describe 'an article' do
    def article
      ::Article.search('Comment1').records.first
    end

    context 'with a comment added' do
      before(:each) do
        article.comments.create(body: 'Comment2')

        Article.__elasticsearch__.refresh_index!
      end

      specify {
        expect(Article.search('Comment1').records.first).not_to be_nil
        expect(Article.search('Comment2').records.first).not_to be_nil
      }
    end

    context 'when a comment destroyed' do
      before(:each) do
        article.comments.first.destroy

        Article.__elasticsearch__.refresh_index!
      end

      specify 'the article is updated' do
        expect(Article.search('Comment1').records).to be_empty
      end

      specify 'the comment becomes unsearchable' do
        expect(Comment.search('Comment1').records).to be_empty
      end
    end
  end
end
