# frozen_string_literal: true

require_relative "github_resolver/version"
require 'pronto'

module Pronto
  module Formatter
    class GithubPullRequestReviewFormatter < PullRequestFormatter
    end
  end
end

module Pronto
  module GithubResolver
  end
end
