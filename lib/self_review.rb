require "dry/cli"
require "dry/configurable"
require "dry/container"
require "dry/auto_inject"
require "rainbow"
require "octokit"
require_relative "self_review/config"

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
        puts

        config = Config.load

        puts Rainbow("GitHub Configuration").bright.yellow
        puts "To use GitHub integration, you need a personal access token."
        puts "Visit: https://github.com/settings/tokens"
        puts "Required scopes: repo (for private repos) or public_repo (for public repos)"
        puts
        print "GitHub personal access token (leave blank to skip): "
        github_token = $stdin.gets.chomp
        config["github_token"] = github_token unless github_token.empty?

        puts
        puts Rainbow("Jira Configuration").bright.yellow
        puts "To use Jira integration, you need your Jira URL and API token."
        puts "Visit: https://id.atlassian.com/manage-profile/security/api-tokens"
        puts
        print "Jira URL (e.g., https://company.atlassian.net) [leave blank to skip]: "
        jira_url = $stdin.gets.chomp
        unless jira_url.empty?
          config["jira_url"] = jira_url
          print "Jira username/email: "
          jira_username = $stdin.gets.chomp
          config["jira_username"] = jira_username
          print "Jira API token: "
          jira_token = $stdin.gets.chomp
          config["jira_token"] = jira_token
        end

        Config.save(config)
        puts
        puts Rainbow("Configuration saved to #{Config.config_file}").bright.green
        puts "You can run this command again anytime to update your settings."
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
