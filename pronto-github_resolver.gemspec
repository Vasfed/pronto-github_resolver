# frozen_string_literal: true

require_relative "lib/pronto/github_resolver/version"

Gem::Specification.new do |spec|
  spec.name = "pronto-github_resolver"
  spec.version = Pronto::GithubResolver::VERSION
  spec.authors = ["Vasily Fedoseyev"]
  spec.email = ["vasilyfedoseyev@gmail.com"]

  spec.summary = "Pronto formatter that marks resolved comments"
  spec.homepage = "https://github.com/Vasfed/pronto-github_resolver"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "pronto", "~> 0.11"
end
