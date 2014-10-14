# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'elasticsearch/model/extensions/version'

Gem::Specification.new do |spec|
  spec.name          = "elasticsearch-model-extensions"
  spec.version       = Elasticsearch::Model::Extensions::VERSION
  spec.authors       = ["Yusuke KUOKA"]
  spec.email         = ["yusuke.kuoka@crowdworks.co.jp"]
  spec.summary       = %q{A set of extensions for elasticsearch-model which aims to ease the burden of things like re-indexing, verbose/complex mapping that you may face once you started using elasticsearch seriously.}
  spec.description   = %q{A set of extensions for elasticsearch-model which aims to ease the burden of things like re-indexing, verbose/complex mapping.}
  spec.homepage      = "https://github.com/crowdworks/elasticsearch-model-extensions"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
