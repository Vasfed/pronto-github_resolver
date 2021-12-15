# Pronto::GithubResolver
[![Gem Version](https://badge.fury.io/rb/pronto-github_resolver.svg)](https://badge.fury.io/rb/pronto-github_resolver)

Pronto formatter to resolve old pronto messages in pull requests.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pronto-github_resolver', require: false
```

And then execute:
```sh
bundle install
```

Use pronto's `github_pr_review` formatter in your CI, for example:
```yml
- name: Run pronto
  run: bundle exec pronto run -f github_status github_pr_review
  env:
    PRONTO_GITHUB_ACCESS_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    PRONTO_PULL_REQUEST_ID: ${{ github.event.pull_request.number }}
    PRONTO_GITHUB_BOT_ID: 12345678 # replace with your bot user id
```

## Usage

Pronto will pick up this from gemfile automatically.

- When any of pronto runners emits message with level `:error` or `:fatal` - generated PR review will have resolution 'REQUEST_CHANGES', and default in other cases.
- On each run comment threads where message is no longer generated will be marked as resolved.
- Set ENV['PRONTO_GITHUB_BOT_ID'] to github id of your bot user (by default it's name `github-actions[bot]`, but id is different).
  This enables posting PR 'APPROVE' review by bot after all messages are resolved.

### Getting bot's id

At the time of writing, github for unknown reason does not allow bots to get own id by calling `/user`.
If you know how to do this without user's effort - please let me know in [issues](https://github.com/Vasfed/pronto-github_resolver/issues).

You can look up bot's user id by doing

```sh
curl -u "your_user:your_token" https://api.github.com/repos/[organization]/[repo]/pulls/[pull_id]/reviews
```
on a pull request where the bot has posted a review.

Personal Access Token is generated in [developer settings in your GitHub profile](https://github.com/settings/tokens).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pronto-github_resolver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
