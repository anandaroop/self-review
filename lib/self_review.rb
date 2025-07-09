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

  module Commands
    class Help < Dry::CLI::Command
      desc "Display help information"

      def call(**)
        puts Rainbow("self-review").bright.blue
        puts
        puts "Usage: self-review [COMMAND]"
        puts
        puts Rainbow("Commands:").bright
        puts "  help     Display this help message"
        puts "  setup    Configure API credentials"
        puts "  fetch    Fetch recent work from GitHub and Jira"
        puts "  analyze  Analyze recent work and generate summary"
        puts
        puts Rainbow("Examples:").bright
        puts "  self-review help"
        puts "  self-review setup"
        puts "  self-review fetch --since=2024-01-01"
        puts "  self-review analyze"
        puts
        puts Rainbow("For more information, visit:").bright
        puts "https://github.com/username/self-review"
      end
    end

    class Setup < Dry::CLI::Command
      desc "Configure API credentials"

      def call(**)
        puts Rainbow("Setting up self-review...").bright.blue
        puts "This feature is not yet implemented."
      end
    end

    class Fetch < Dry::CLI::Command
      desc "Fetch recent work from GitHub and Jira"
      option :since, desc: "Fetch work since this date (YYYY-MM-DD)"

      def call(since: nil, **)
        puts Rainbow("Fetching recent work...").bright.blue
        puts "Since: #{since || "1 month ago"}"
        puts "This feature is not yet implemented."
      end
    end

    class Analyze < Dry::CLI::Command
      desc "Analyze recent work and generate summary"

      def call(**)
        puts Rainbow("Analyzing recent work...").bright.blue
        puts "This feature is not yet implemented."
      end
    end
  end

  class CLI
    extend Dry::CLI::Registry

    register "help", Commands::Help, aliases: ["h", "--help"]
    register "setup", Commands::Setup
    register "fetch", Commands::Fetch
    register "analyze", Commands::Analyze
  end
end
