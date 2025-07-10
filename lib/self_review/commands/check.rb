module SelfReview
  module Commands
    class Check < Dry::CLI::Command
      desc "Check API connectivity"

      option :verbose, type: :boolean, default: false, desc: "Enable verbose API logging"

      def call(verbose: false, **)
        puts Rainbow("Checking API connectivity...").bright.blue
        puts

        config = Config.load

        if config.empty?
          puts Rainbow("No credentials configured. Run 'self-review setup' first.").red
          return
        end

        # Check GitHub
        github_result = ApiChecker.check_github(config["github_token"], verbose: verbose)
        print_status("GitHub", github_result)

        # Check Jira
        jira_result = ApiChecker.check_jira(
          config["jira_url"],
          config["jira_username"],
          config["jira_token"],
          verbose: verbose
        )
        print_status("Jira", jira_result)

        # Check LLM APIs
        llm_result = check_llm_apis(config)
        print_status("LLM", llm_result)

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

        if has_llm_config?(config)
          total_apis += 1
          working_apis += 1 if llm_result[:status] == :success
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

      def check_llm_apis(config)
        if !has_llm_config?(config)
          return {status: :missing, message: "No LLM API keys configured"}
        end

        begin
          # Test with a simple prompt
          LLMService.client(verbose: false).ask("Hello, respond with just 'OK'")
          {status: :success, message: "LLM API accessible"}
        rescue => e
          {status: :error, message: "LLM API error: #{e.message}"}
        end
      end

      def has_llm_config?(config)
        (!config["anthropic_api_key"].nil? && !config["anthropic_api_key"].empty?) ||
          (!config["openai_api_key"].nil? && !config["openai_api_key"].empty?)
      end

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
  end
end
