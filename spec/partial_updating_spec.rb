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

  let(:as_json_options) {
    described_class.build_as_json_options(klass: Article, props: Article.mappings.to_hash[Article.document_type.intern][:properties])
  }

  subject {
    Article.last
  }

  specify {
    expect(as_json_options).to include(methods: :num_comments)
  }

  specify {
    expect(subject.build_partial_document_for_update(:comments)).to include(:comments, :num_comments)
  }
end
