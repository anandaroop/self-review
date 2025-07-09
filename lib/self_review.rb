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
        puts "  check    Check API connectivity"
        puts "  fetch    Fetch recent work from GitHub and Jira"
        puts "  analyze  Analyze recent work and generate summary"
        puts
        puts Rainbow("Examples:").bright
        puts "  self-review help"
        puts "  self-review setup"
        puts "  self-review check"
        puts "  self-review fetch --since=2024-01-01"
        puts "  self-review analyze"
        puts
        puts Rainbow("For more information, visit:").bright
        puts "https://github.com/username/self-review"
      end
    end

    class Check < Dry::CLI::Command
      desc "Check API connectivity"

      def call(**)
        puts Rainbow("Checking API connectivity...").bright.blue
        puts

        config = Config.load

        if config.empty?
          puts Rainbow("No credentials configured. Run 'self-review setup' first.").red
          return
        end

        # Check GitHub
        github_result = ApiChecker.check_github(config["github_token"])
        print_status("GitHub", github_result)

        # Check Jira
        jira_result = ApiChecker.check_jira(
          config["jira_url"],
          config["jira_username"],
          config["jira_token"]
        )
        print_status("Jira", jira_result)

        puts

        working_apis = 0
        total_apis = 0

        if !config["github_token"].nil? && !config["github_token"].empty?
          total_apis += 1
          working_apis += 1 if github_result[:status] == :success
        end

        if !config["jira_url"].nil? && !config["jira_url"].empty?
          total_apis += 1
          working_apis += 1 if jira_result[:status] == :success
        end

        if total_apis == 0
          puts Rainbow("No APIs configured. Run 'self-review setup' first.").yellow
        elsif working_apis == total_apis
          puts Rainbow("#{working_apis}/#{total_apis} APIs are working correctly.").bright.green
        elsif working_apis > 0
          puts Rainbow("#{working_apis}/#{total_apis} APIs are working correctly.").yellow
        else
          puts Rainbow("0/#{total_apis} APIs are accessible. Please check your configuration.").bright.red
        end
      end

      private

      def print_status(service, result)
        case result[:status]
        when :success
          puts "#{service.ljust(10)} #{Rainbow("✓").green} #{result[:message]}"
        when :error
          puts "#{service.ljust(10)} #{Rainbow("✗").red} #{result[:message]}"
        when :missing
          puts "#{service.ljust(10)} #{Rainbow("○").yellow} #{result[:message]}"
        end
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
        puts

        config = Config.load

        if config.empty?
          puts Rainbow("No credentials configured. Run 'self-review setup' first.").red
          return
        end

        since_date = since ? Date.parse(since) : nil
        github_prs = []
        jira_tickets = []

        # Fetch GitHub PRs
        if config["github_token"] && !config["github_token"].empty?
          puts "Fetching from GitHub..."
          github_prs = GitHubClient.fetch_merged_prs(config["github_token"], since_date)
          puts "Found #{github_prs.length} merged PRs"
        end

        # Fetch Jira tickets
        if config["jira_url"] && !config["jira_url"].empty?
          puts "Fetching from Jira..."
          jira_tickets = JiraClient.fetch_done_tickets(
            config["jira_url"],
            config["jira_username"],
            config["jira_token"],
            since_date
          )
          puts "Found #{jira_tickets.length} completed tickets"
        end

        # Generate YAML file
        timestamp = Time.now.strftime("%y%m%d-%H%M%S")
        filename = "recent-work-#{timestamp}.yml"

        yaml_content = generate_yaml(github_prs, jira_tickets, since_date)
        File.write(filename, yaml_content)

        puts
        puts Rainbow("Work data saved to #{filename}").bright.green
        puts "Total items: #{github_prs.length + jira_tickets.length}"
      end

      private

      def generate_yaml(github_prs, jira_tickets, since_date)
        data = {
          "metadata" => {
            "generated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "since_date" => since_date ? since_date.strftime("%Y-%m-%d") : (Date.today - 30).strftime("%Y-%m-%d"),
            "default_period" => since_date.nil?,
            "total_items" => github_prs.length + jira_tickets.length
          },
          "github_prs" => github_prs.map { |pr| pr.transform_keys(&:to_s) },
          "jira_tickets" => jira_tickets.map { |ticket| ticket.transform_keys(&:to_s) }
        }

        YAML.dump(data)
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
    register "check", Commands::Check
    register "fetch", Commands::Fetch
    register "analyze", Commands::Analyze
  end
end
