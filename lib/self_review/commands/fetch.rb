module SelfReview
  module Commands
    class Fetch < Dry::CLI::Command
      desc "Fetch recent work from GitHub and Jira"
      argument :date_range, required: false, desc: "Natural language date range (e.g., 'last 3 months', 'q2 of this year')"
      option :since, desc: "Fetch work since this date (YYYY-MM-DD format)"
      option :verbose, type: :boolean, default: false, desc: "Enable verbose API logging"

      def call(date_range: nil, since: nil, verbose: false, **)
        puts Rainbow("Fetching recent work...").bright.blue
        puts

        config = Config.load

        if config.empty?
          puts Rainbow("No credentials configured. Run 'self-review setup' first.").red
          return
        end

        # Parse the date range - prioritize positional argument over --since option
        date_input = date_range || since
        parsed_date_range = parse_date_range(date_input, verbose)
        since_date = parsed_date_range[:start_date]
        end_date = parsed_date_range[:end_date]

        # Display the parsed date range to user
        if date_input
          puts "Date range: #{since_date.strftime("%Y-%m-%d")} to #{end_date.strftime("%Y-%m-%d")}"
          if parsed_date_range[:explanation]
            puts Rainbow("Interpreted as: #{parsed_date_range[:explanation]}").faint
          end
          puts
        end

        github_prs = []
        jira_tickets = []

        # Fetch GitHub PRs
        if config["github_token"] && !config["github_token"].empty?
          puts "Fetching from GitHub..."
          github_prs = GitHubClient.fetch_merged_prs(config["github_token"], since_date, end_date, verbose: verbose)
          puts "Found #{github_prs.length} merged PRs"
        end

        # Fetch Jira tickets
        if config["jira_url"] && !config["jira_url"].empty?
          puts "Fetching from Jira..."
          jira_tickets = JiraClient.fetch_done_tickets(
            config["jira_url"],
            config["jira_username"],
            config["jira_token"],
            since_date,
            end_date,
            verbose: verbose
          )
          puts "Found #{jira_tickets.length} completed tickets"
        end

        # Generate YAML file
        timestamp = Time.now.strftime("%y%m%d-%H%M%S")
        filename = "recent-work-#{timestamp}.yml"

        yaml_content = generate_yaml(github_prs, jira_tickets, parsed_date_range)
        File.write(filename, yaml_content)

        puts
        puts Rainbow("Work data saved to #{filename}").bright.green
        puts "Total items: #{github_prs.length + jira_tickets.length}"
      end

      private

      def parse_date_range(date_input, verbose)
        if date_input
          begin
            DateParser.parse(date_input, verbose: verbose)
          rescue DateParser::ParseError => e
            puts Rainbow("Error parsing date: #{e.message}").red
            puts Rainbow("Using default range (last 30 days)").yellow
            {
              start_date: Date.today - 30,
              end_date: Date.today,
              source: "fallback",
              confidence: "low"
            }
          end
        else
          # Default to last 30 days
          {
            start_date: Date.today - 30,
            end_date: Date.today,
            source: "default",
            confidence: "high"
          }
        end
      end

      def generate_yaml(github_prs, jira_tickets, date_range)
        data = {
          "metadata" => {
            "generated_at" => Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            "start_date" => date_range[:start_date].strftime("%Y-%m-%d"),
            "end_date" => date_range[:end_date].strftime("%Y-%m-%d"),
            "date_source" => date_range[:source],
            "date_confidence" => date_range[:confidence],
            "date_explanation" => date_range[:explanation],
            "total_items" => github_prs.length + jira_tickets.length
          },
          "github_prs" => github_prs.map { |pr| pr.transform_keys(&:to_s) },
          "jira_tickets" => jira_tickets.map { |ticket| ticket.transform_keys(&:to_s) }
        }

        YAML.dump(data)
      end
    end
  end
end
