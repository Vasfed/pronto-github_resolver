# frozen_string_literal: true

require_relative "github_resolver/version"
require 'pronto'

module Pronto

  class Github < Client
    # pronto messes up relative paths and does not have tests for this, patch to add repo.path.join
    def pull_comments(sha)
      @comment_cache["#{pull_id}/#{sha}"] ||= begin
        client.pull_comments(slug, pull_id).map do |comment|
          Comment.new(sha, comment.body, @repo.path.join(comment.path),
                      comment.position || comment.original_position)
        end
      end
    rescue Octokit::NotFound => e
      @config.logger.log("Error raised and rescued: #{e}")
      msg = "Pull request for sha #{sha} with id #{pull_id} was not found."
      raise Pronto::Error, msg
    end

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

    def get_review_threads
      owner, repo_name = (slug || "").split('/')
      res = client.post :graphql, { query: <<~GQL }.to_json
        query getUserId {
          repository(owner: "#{owner}", name: "#{repo_name}") {
            pullRequest: issueOrPullRequest(number: #{pull_id}) {
              ... on PullRequest {
                reviewThreads(last:100) {
                    totalCount
                    nodes {
                        id
                        comments(last: 10) {
                            nodes {
                                viewerDidAuthor
                                path position body
                            }
                        }
                    }
                }
              }
            }
          }
        }
      GQL

      if res.errors || !res.data
        # ex: [{:message=>"Parse error on \"11\" (INT) at [1, 22]", :locations=>[{:line=>1, :column=>22}]}]
        # TODO: handle errors
        return []
      end

      res.data.repository.pullRequest.reviewThreads.nodes.to_h { |node|
        [
          node.id,
          node.comments.nodes.map{ |comment|
            {
              authored: comment.viewerDidAuthor,
              path: comment.path, position: comment.position, body: comment.body
            }
          }
        ]
      }
    end

    def resolve_review_threads(node_ids)
      return unless node_ids.any?

      owner, repo_name = (slug || "").split('/')
      query = <<~GQL
        mutation {
          #{
            node_ids.each_with_index.map {|id, index|
              "q#{index}: resolveReviewThread(input: { threadId: \"#{id}\" }){ thread { id } } "
            }.join("\n")
          }
        }
      GQL
      client.post :graphql, { query: query }.to_json
    end
  end

  module Formatter
    module GithubResolving
      def format(messages, repo, patches)
        client = client_module.new(repo)
        existing = existing_comments(messages, client, repo)
        comments = new_comments(messages, patches)
        additions = remove_duplicate_comments(existing, comments)

        # TODO: we can reuse some threads from graphql for existing messages detection (but there's no pagination)
        resolve_old_messages(client, repo, comments)

        if comments.none?
          bot_reviews = client.existing_pull_request_reviews.select { |review| review.user.type == 'Bot' }
          if bot_reviews.any?
            current_bot_review_status = bot_reviews.inject(nil) do |prev_status, review|
              next prev_status unless review_by_this_bot?(review)

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

      def review_by_this_bot?(review)
        ENV['PRONTO_GITHUB_BOT_ID'] && review.user.id == ENV['PRONTO_GITHUB_BOT_ID'].to_i
      end

      def submit_comments(client, comments, event: nil)
        client.publish_pull_request_comments(comments, event: event)
      rescue Octokit::UnprocessableEntity, HTTParty::Error => e
        $stderr.puts "Failed to post: #{e.message}"
      end

      def resolve_old_messages(client, repo, actual_comments)
        thread_ids_to_resolve = []
        client.get_review_threads.each_pair do |thread_id, thread_comments|
          next unless thread_comments.all? do |comment|
            comment[:authored] &&
              (actual_comments[[repo.path.join(comment[:path]), comment[:position]]] || []).none? { |actual_comment|
                comment[:body].include?(actual_comment.body)
              }
          end
          thread_ids_to_resolve << thread_id
        end
        client.resolve_review_threads(thread_ids_to_resolve)
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
