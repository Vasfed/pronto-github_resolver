# frozen_string_literal: true

module Pronto
  # extend stock pronto github client wrapper
  class Github < Pronto::Client
    # original, but with event param
    def publish_pull_request_comments(comments, event: nil)
      comments_left = comments.clone
      while comments_left.any?
        comments_to_publish = comments_left.slice!(0, warnings_per_review)
        create_pull_request_review(comments_to_publish, event: event)
      end
    end

    # original, but with event param
    def create_pull_request_review(comments, event: nil)
      options = {
        event: event || @config.github_review_type,
        accept: "application/vnd.github.v3.diff+json", # https://developer.github.com/v3/pulls/reviews/#create-a-pull-request-review
        comments: comments.map do |comment|
          { path: comment.path, position: comment.position, body: comment.body }
        end
      }
      client.create_pull_request_review(slug, pull_id, options)
    end

    def approve_pull_request(message = "")
      client.create_pull_request_review(
        slug, pull_id,
        { event: "APPROVE", body: message, accept: "application/vnd.github.v3.diff+json" }
      )
    end

    def existing_pull_request_reviews
      client.pull_request_reviews(slug, pull_id)
    end

    GET_REVIEW_THREADS_QUERY = <<~GQL
      query getReviewThreadIds($owner: String!, $name: String!, $pull_num: Int!) {
        repository(owner: $owner, name: $name) {
          pullRequest: issueOrPullRequest(number: $pull_num) {
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

    def fetch_review_threads # rubocop:disable Metrics/MethodLength
      owner, repo_name = slug.split("/")
      res = client.post :graphql, {
        query: GET_REVIEW_THREADS_QUERY,
        variables: { owner: owner, name: repo_name, pull_num: pull_id }
      }.to_json

      return [] if res.errors || !res.data # TODO: handle errors

      res.data.repository.pullRequest.reviewThreads.nodes.to_h do |node|
        [
          node.id,
          node.comments.nodes.map do |comment|
            { authored: comment.viewerDidAuthor, path: comment.path, position: comment.position, body: comment.body }
          end
        ]
      end
    end

    def resolve_review_threads(node_ids)
      return unless node_ids.any?

      query = <<~GQL
        mutation {
          #{node_ids.each_with_index.map do |id, index|
              "q#{index}: resolveReviewThread(input: { threadId: \"#{id}\" }){ thread { id } } "
            end.join("\n")}
        }
      GQL
      client.post :graphql, { query: query }.to_json
    end
  end
end
