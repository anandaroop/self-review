module SelfReview
  module Commands
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

        puts
        puts Rainbow("LLM Configuration").bright.yellow
        puts "To use AI analysis, you need an API key for either Anthropic Claude or OpenAI GPT."
        puts "Anthropic Claude API: https://console.anthropic.com/"
        puts "OpenAI GPT API: https://platform.openai.com/api-keys"
        puts
        print "Anthropic API key (leave blank to skip): "
        anthropic_key = $stdin.gets.chomp
        config["anthropic_api_key"] = anthropic_key unless anthropic_key.empty?

        print "OpenAI API key (leave blank to skip): "
        openai_key = $stdin.gets.chomp
        config["openai_api_key"] = openai_key unless openai_key.empty?

        Config.save(config)
        puts
        puts Rainbow("Configuration saved to #{Config.config_file}").bright.green
        puts "You can run this command again anytime to update your settings."
      end
    end
  end
end
