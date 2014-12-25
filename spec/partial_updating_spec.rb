require 'elasticsearch/model/extensions/all'

RSpec.describe Elasticsearch::Model::Extensions::PartialUpdating do
  before(:each) do
    load 'setup/articles_with_comments.rb'
  end

  after :each do
    ActiveRecord::Schema.define(:version => 2) do
      drop_table :comments
      drop_table :articles
    end
  end

  subject {
    Article.last
  }

  specify {
    expect(subject.respond_to? :partially_update_document).to be_truthy
  }

  specify {
    expect(subject.as_indexed_json).to eq(
                                         "comments"=>[{"body"=>'Comment1'}],
                                         "num_comments"=>1,
                                         "title"=>'Coding',
                                         "created_at"=>subject.created_at
                                       )
  }

  describe Elasticsearch::Model::Extensions::PartialUpdating::PartialUpdater do
    subject {
      described_class.new(Article)
    }

    specify {
      expect(subject.as_json_options).to include(methods: "num_comments")
    }

    specify {
      expect(subject.build_partial_document_for_update(record: Article.last, changed_attributes: [:comments])).to include(:comments, :num_comments)
    }

    def partially_updating_a_record
      article = Article.last
      subject.update_document(id: article.id, doc: { comments: [ { body: 'ModifiedComment ' } ] })
      Article.__elasticsearch__.refresh_index!
    end

    def number_of_articles_for_the_new_comment
      Article.search('ModifiedComment').records.size
    end

    specify {
      expect { partially_updating_a_record }.to change { number_of_articles_for_the_new_comment }.by(1)
    }
  end
end

