require 'elasticsearch/model/extensions/all'

RSpec.shared_examples 'a document updates outer documents on changed' do
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

    context 'with a comment updated' do
      before(:each) do
        article.comments.first.update_attributes body: 'Comment3'

        Article.__elasticsearch__.refresh_index!
      end

      specify {
        expect(Article.search('Comment1').records.first).to be_nil
      }

      specify {
        expect(Article.search('Comment3').records.first).not_to be_nil
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

RSpec.describe Elasticsearch::Model::Extensions::OuterDocumentUpdating do
  context 'having articles with comments' do
    before(:each) do
      load 'setup/articles_with_comments.rb'
    end

    after :each do
      ActiveRecord::Schema.define(:version => 2) do
        drop_table :comments
        drop_table :articles
      end
    end

    it_behaves_like 'a document updates outer documents on changed'
  end

  context 'having articles with comments and delayed jobs' do
    before(:each) do
      load 'setup/articles_with_comments_and_delayed_jobs.rb'
    end

    after :each do
      ActiveRecord::Schema.define(:version => 2) do
        drop_table :comments
        drop_table :articles
        drop_table :delayed_jobs
      end
    end

    it_behaves_like 'a document updates outer documents on changed'
  end
end
