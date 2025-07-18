require "dry/cli"
require "dry/configurable"
require "dry/container"
require "dry/auto_inject"
require "rainbow"
require "octokit"
require "yaml"
require_relative "self_review/config"
require_relative "self_review/api_checker"
require_relative "self_review/github_client"
require_relative "self_review/jira_client"
require_relative "self_review/llm_service"
require_relative "self_review/markdown_renderer"
require_relative "self_review/date_parser"
require_relative "self_review/terminal_link"
require_relative "self_review/commands/help"
require_relative "self_review/commands/setup"
require_relative "self_review/commands/check"
require_relative "self_review/commands/fetch"
require_relative "self_review/commands/analyze"
require_relative "self_review/commands/auto_analyze"

module SelfReview
  class Container
    extend Dry::Container::Mixin

    setting :github_token, default: nil
    setting :jira_url, default: nil
    setting :jira_username, default: nil
    setting :jira_token, default: nil
  end

  AutoInject = Dry::AutoInject(Container)

  module Commands
  end

  class CLI
    extend Dry::CLI::Registry

    register "help", Commands::Help, aliases: ["h", "--help"]
    register "setup", Commands::Setup
    register "check", Commands::Check
    register "fetch", Commands::Fetch
    register "analyze", Commands::Analyze
  end
end
