# frozen_string_literal: true

require_relative "github_resolver/version"
require 'pronto'

module Pronto

  class Github < Client
    def publish_pull_request_comments(comments, event: nil)
      comments_left = comments.clone
      while comments_left.any?
        comments_to_publish = comments_left.slice!(0, warnings_per_review)
        create_pull_request_review(comments_to_publish, event: event)
      end
    end

    def create_pull_request_review(comments, event: nil)
      options = {
        event: event || @config.github_review_type,
        accept: 'application/vnd.github.v3.diff+json', # https://developer.github.com/v3/pulls/reviews/#create-a-pull-request-review
        comments: comments.map do |comment|
          {
            path:     comment.path,
            position: comment.position,
            body:     comment.body
          }
        end
      }
      client.create_pull_request_review(slug, pull_id, options)
    end

    def approve_pull_request(message=nil)
      client.create_pull_request_review(slug, pull_id, {
        event: 'APPROVE', body: message, accept: 'application/vnd.github.v3.diff+json'
      })
    end

    def existing_pull_request_reviews
      client.pull_request_reviews(slug, pull_id)
    end

    def bot_user_id
      client.user.id
    end
  end

  module Formatter
    module GithubResolving
      def format(messages, repo, patches)
        client = client_module.new(repo)
        existing = existing_comments(messages, client, repo)
        comments = new_comments(messages, patches)
        additions = remove_duplicate_comments(existing, comments)

        if comments.none?
          bot_reviews = client.existing_pull_request_reviews.select { |review| review.user.type == 'Bot' }
          if bot_reviews.any?
            bot_id = client.bot_user_id
            current_bot_review_status = bot_reviews.inject(nil) do |prev_status, review|
              next prev_status unless review.user.id == bot_id

              case review.state
              when 'CHANGES_REQUESTED' then review.state
              when 'APPROVED' then nil
              else
                prev_status
              end
            end

            client.approve_pull_request if current_bot_review_status == 'CHANGES_REQUESTED'
          end
        else
          submit_comments(
            client, additions,
            event: messages.any? { |message| %i[error fatal].include?(message.level) } && 'REQUEST_CHANGES' || nil
          )
        end

        "#{additions.count} Pronto messages posted to #{pretty_name}"
      end

      def submit_comments(client, comments, event: nil)
        client.publish_pull_request_comments(comments, event: event)
      rescue Octokit::UnprocessableEntity, HTTParty::Error => e
        $stderr.puts "Failed to post: #{e.message}"
      end
    end

    class GithubPullRequestResolvingReviewFormatter < PullRequestFormatter
      prepend GithubResolving
    end

    Pronto::Formatter::GithubPullRequestReviewFormatter.prepend(GithubResolving)
  end
end

module Pronto
  module GithubResolver
  end
end
