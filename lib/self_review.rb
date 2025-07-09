require "dry/cli"
require "dry/configurable"
require "dry/container"
require "dry/auto_inject"
require "rainbow"
require "octokit"

module SelfReview
  class Container
    extend Dry::Container::Mixin

    setting :github_token, default: nil
    setting :jira_url, default: nil
    setting :jira_username, default: nil
    setting :jira_token, default: nil
  end

  AutoInject = Dry::AutoInject(Container)

  class CLI < Dry::CLI::Command
    desc "Self-review CLI tool"

    def call(**)
      puts Rainbow("Welcome to self-review!").green
      puts "Run 'self-review help' for usage instructions."
    end
  end
end
