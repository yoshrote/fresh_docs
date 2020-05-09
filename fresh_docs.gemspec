# frozen_string_literal: true
require_relative "lib/fresh_docs/version"

Gem::Specification.new do |spec|
  spec.name          = 'fresh_docs'
  spec.version       = FreshDocs::VERSION
  spec.authors       = [
    "Joshua Forman",
  ]
  spec.summary       = 'a tool to check that documentation up-to-date'
  spec.files         = %x(git ls-files -z).split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|)/|\.gem$})
  end
  spec.executables << 'yardcheck'
  spec.require_paths = ["lib"]
end
