# frozen_string_literal: true

require "pronto"
require_relative "github_resolver/version"
require_relative "github_resolver/github_client_ext"

module Pronto
  module Formatter
    # monkey-patch stock formatter with altered behavior
    module GithubResolving
      # TODO: we can reuse some threads from graphql for existing messages detection (but there's no pagination)
      def format(messages, repo, patches)
        client = client_module.new(repo)
        existing = existing_comments(messages, client, repo)
        comments = new_comments(messages, patches)
        additions = remove_duplicate_comments(existing, comments)

        resolve_old_messages(client, comments)
        submit_review(comments, messages, client, additions)

        "#{additions.count} Pronto messages posted to #{pretty_name}"
      end

      def submit_review(comments, messages, client, additions)
        return post_approve_if_needed(client) if comments.none?

        request_changes_at = %i[error fatal].freeze
        request_changes = messages.any? { |message| request_changes_at.include?(message.level) } && "REQUEST_CHANGES"
        submit_comments(client, additions, event: request_changes || nil)
      end

      def post_approve_if_needed(client)
        bot_reviews = client.existing_pull_request_reviews.select { |review| review.user.type == "Bot" }
        return if bot_reviews.none?

        current_bot_review_status = bot_reviews.inject(nil) do |prev_status, review|
          if review_by_this_bot?(review)
            next review.state if review.state == "CHANGES_REQUESTED"
            next nil if review.state == "APPROVED"
          end
          prev_status
        end

        client.approve_pull_request if current_bot_review_status == "CHANGES_REQUESTED"
      end

      def review_by_this_bot?(review)
        ENV["PRONTO_GITHUB_BOT_ID"] && review.user.id == ENV["PRONTO_GITHUB_BOT_ID"].to_i
      end

      # copied from upstream, added event param
      def submit_comments(client, comments, event: nil)
        client.publish_pull_request_comments(comments, event: event)
      rescue Octokit::UnprocessableEntity, HTTParty::Error => e
        $stderr.puts "Failed to post: #{e.message}" # rubocop:disable Style/StderrPuts like in upstream
      end

      def resolve_old_messages(client, actual_comments)
        thread_ids_to_resolve = client.fetch_review_threads.select do |_thread_id, thread_comments|
          thread_comments.all? do |comment|
            comment[:authored] &&
              (actual_comments[[comment[:path], comment[:position]]] || []).none? do |actual_comment|
                comment[:body].include?(actual_comment.body)
              end
          end
        end.keys
        client.resolve_review_threads(thread_ids_to_resolve)
      end
    end
  end
end

# if pronto did not have formatters array frozen - instead of monkeypatch we might have
# class GithubPullRequestResolvingReviewFormatter < PullRequestFormatter
#   prepend GithubResolving
# end
Pronto::Formatter::GithubPullRequestReviewFormatter.prepend(Pronto::Formatter::GithubResolving)
