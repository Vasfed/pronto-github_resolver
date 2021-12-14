# Pronto::GithubResolver

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/pronto/github_resolver`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pronto-github_resolver'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install pronto-github_resolver

## Usage

- When any of pronto runners emits message with level `:error` or `:fatal` - generated PR review will have resolution 'REQUEST_CHANGES', and default in other cases.
- On each run comment threads where message is no longer generated will be marked as resolved.
- Set ENV['PRONTO_GITHUB_BOT_ID'] to github id of your bot user. This enables posting PR 'APPROVE' review by bot after all messages are resolved.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pronto-github_resolver.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
