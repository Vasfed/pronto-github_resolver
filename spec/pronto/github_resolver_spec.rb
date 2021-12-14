# frozen_string_literal: true

RSpec.describe Pronto::GithubResolver do
  it "has a version number" do
    expect(Pronto::GithubResolver::VERSION).not_to be nil
  end
end

RSpec.describe Pronto::Formatter::GithubPullRequestReviewFormatter do
  let(:formatter) { described_class.new }

  let(:repo) { Pronto::Git::Repository.new('test.git') }

  around do |spec|
    # change to repository workdir (for paths to match)
    Dir.chdir('spec/fixtures') do
      spec.run
    end
  end

  describe '#format' do
    subject { formatter.format(messages, repo, patches) }
    let(:patches) { repo.diff('change^') }
    let(:patch) { patches.first }
    let(:message_level) { :info }
    let(:message) { Pronto::Message.new(patch.new_file_path, patch.added_lines.first, message_level, 'New message') }
    let(:messages) { [message, message] }
    let(:existing_messages) { [] }
    let(:existing_threads) { {} }
    let(:existing_reviews) { [] }

    before do
      ENV['PRONTO_PULL_REQUEST_ID'] = '10'
      ENV['PRONTO_GITHUB_BOT_ID'] = '4189'
      allow_any_instance_of(Octokit::Client).to receive(:pull_comments).and_return(existing_messages)
      allow_any_instance_of(Octokit::Client).to receive(:pull_request_reviews).and_return(existing_reviews)
      allow_any_instance_of(Pronto::Github).to receive(:get_review_threads).and_return(existing_threads)
    end

    it "adds comment" do
      expect_any_instance_of(Octokit::Client).to receive(:create_pull_request_review).once.with("test/test", 10,
        a_hash_including(
          event: 'COMMENT',
          comments: [ a_hash_including(body: 'New message') ]
        )
      )

      subject
    end

    context "when message is error" do
      let(:message_level) { :error }

      it "adds comment with REQUEST_CHANGES" do
        expect_any_instance_of(Octokit::Client).to receive(:create_pull_request_review).once.with("test/test", 10,
          a_hash_including(event: 'REQUEST_CHANGES', comments: [ a_hash_including(body: 'New message') ])
        )

        subject
      end
    end

    context "when previous comments are fixed" do
      let(:existing_messages) do
        JSON.parse <<~JSON, object_class: OpenStruct
          [
            {
              "pull_request_review_id": 42,
              "id": 100123,
              "node_id": "MDI0OlB1bGxSZXF1ZXN0UmV2aWV3Q29tbWVudDEw",
              "diff_hunk": "@@ -16,33 +16,40 @@ public class Connection : IConnection...",
              "path": "somefile.txt",
              "position": 1,
              "original_position": 4,
              "commit_id": "6dcb09b5b57875f334f61aebed695e2e4193db5e",
              "original_commit_id": "9c48853fa3dc5c1c3d6f1f1cd1f2743e72652840",
              "user": { "login": "github-actions[bot]", "id": 4189, "node_id": "MDE6Qm90NDE4OQ==", "type": "Bot" },
              "body": "New message"
            }
          ]
        JSON
      end
      let(:existing_threads) do
        {
          "bot_thread_with_user" => [
            { authored: true, path: "some_other_file", position: 1, body: "Foo"},
            { authored: false, path: "some_other_file", position: 1, body: "Reply to foo"}
          ],
          "resolved_bot_thread_id" => [{ authored: true, path: "some_other_file", position: 1, body: "Foo"}],
          "active_bot_thread_id" => [{ authored: true, path: "somefile.txt", position: 1, body: "New message" }],
          "user_thread" => [ { authored: false, path: "some_other_file", position: 2, body: "Bar"} ]
        }
      end

      it "resolves these" do
        expect_any_instance_of(Octokit::Client).not_to receive(:create_pull_request_review)
        allow_any_instance_of(Pronto::Github).to receive(:resolve_review_threads).with(["resolved_bot_thread_id"])
        subject
      end
    end

    context "when previous review was with request changes and all fixed" do
      let(:messages) { [] }
      let(:existing_reviews) do
        JSON.parse <<~JSON, object_class: OpenStruct
          [
            {
              "id": 830092384,
              "node_id": "PRR_kwDOAKIEpc4xejRg",
              "user": { "login": "github-actions[bot]", "id": 4189, "node_id": "MDE6Qm90NDE4OQ==", "type": "Bot" },
              "state": "CHANGES_REQUESTED", "body": "",
              "submitted_at": "2021-12-13T11:07:03Z",
              "commit_id": "58b135e26e4e2f36bd6c928fc76aa2f10fdfc923"
            }
          ]
        JSON
      end

      it "approves PR" do
        expect_any_instance_of(Octokit::Client).to receive(:create_pull_request_review).once.with("test/test", 10,
          a_hash_including(
            event: 'APPROVE', # DISMISS ?
            # body: "1 warning fixed, bots are happy"
          )
        )

        subject
      end
    end
  end
end
