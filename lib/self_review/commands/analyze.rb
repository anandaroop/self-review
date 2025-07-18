module SelfReview
  module Commands
    class Analyze < Dry::CLI::Command
      desc "Analyze recent work and generate summary"

      option :verbose, type: :boolean, default: false, desc: "Enable verbose LLM debugging output"
      option :display, type: :string, desc: "Display existing analysis file (provide filename)"

      def call(verbose: false, display: nil, **)
        # If display option is provided, just render the existing file
        if display
          display_analysis_file(display)
          return
        end

        puts Rainbow("Analyzing recent work...").bright.blue
        puts

        # Find the most recent work data file
        yaml_files = Dir.glob("recent-work-*.yml").sort.reverse

        if yaml_files.empty?
          puts Rainbow("No work data found. Run 'self-review fetch' first.").red
          return
        end

        latest_file = yaml_files.first
        puts "Using data from: #{latest_file}"

        # Load and parse the YAML data
        begin
          data = YAML.load_file(latest_file)
          github_prs = data["github_prs"] || []
          jira_tickets = data["jira_tickets"] || []

          puts "Found #{github_prs.length} GitHub PRs and #{jira_tickets.length} Jira tickets"
          puts
        rescue => e
          puts Rainbow("Error loading work data: #{e.message}").red
          return
        end

        # Check LLM configuration
        config = Config.load
        if !has_llm_config?(config)
          puts Rainbow("No LLM API keys configured. Run 'self-review setup' first.").red
          return
        end

        # Cluster the work using LLM
        puts "Clustering work items..."
        clusters = LLMService.cluster_work(github_prs, jira_tickets, verbose: verbose)
        puts "Identified #{clusters.length} work clusters"

        # Add actual work items to clusters
        all_items = github_prs + jira_tickets
        clusters.each do |cluster|
          cluster[:items] = cluster[:item_numbers].map do |num|
            all_items[num - 1] if num <= all_items.length
          end.compact
        end

        # Generate accomplishment summary
        puts "Generating accomplishment summary..."
        accomplishments = LLMService.summarize_accomplishments(clusters, verbose: verbose)

        # Save analysis to file
        timestamp = Time.now.strftime("%y%m%d-%H%M%S")
        filename = "analysis-#{timestamp}.md"

        analysis_content = generate_analysis_markdown(data, clusters, accomplishments)
        File.write(filename, analysis_content)

        puts
        puts Rainbow("Analysis saved to #{filename}").bright.green
        puts "#{clusters.length} clusters identified with #{accomplishments.length} key accomplishments"
        puts
        puts Rainbow("=" * 50).bright.cyan
        puts Rainbow("ANALYSIS RESULTS").bright.cyan.bold
        puts Rainbow("=" * 50).bright.cyan
        puts
        puts MarkdownRenderer.render(analysis_content)
      end

      private

      def display_analysis_file(filename)
        unless File.exist?(filename)
          puts Rainbow("File not found: #{filename}").red
          return
        end

        content = File.read(filename)
        puts Rainbow("=" * 50).bright.cyan
        puts Rainbow("ANALYSIS RESULTS").bright.cyan.bold
        puts Rainbow("=" * 50).bright.cyan
        puts
        puts MarkdownRenderer.render(content)
      end

      def has_llm_config?(config)
        (!config["anthropic_api_key"].nil? && !config["anthropic_api_key"].empty?) ||
          (!config["openai_api_key"].nil? && !config["openai_api_key"].empty?)
      end

      def generate_analysis_markdown(data, clusters, accomplishments)
        metadata = data["metadata"] || {}

        content = []
        content << "# Work Analysis"
        content << ""
        content << "Generated: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"

        # Handle both old and new metadata formats
        if metadata["start_date"] && metadata["end_date"]
          content << "Data period: #{metadata["start_date"]} to #{metadata["end_date"]}"
        elsif metadata["since_date"]
          content << "Data period: #{metadata["since_date"]} to #{metadata["generated_at"]&.split(" ")&.first}"
        end

        content << "Total items analyzed: #{metadata["total_items"]}"
        content << ""

        content << "## Key Accomplishments"
        content << ""
        accomplishments.each do |accomplishment|
          content << "- #{accomplishment}"
        end
        content << ""

        content << "## Work Clusters"
        content << ""
        clusters.each_with_index do |cluster, index|
          content << "### #{index + 1}. #{cluster[:name]}"
          content << ""
          content << cluster[:description]
          content << ""
          content << "**Items (#{cluster[:items].length}):**"
          cluster[:items].each do |item|
            if item["title"]
              # GitHub PR with clickable link icon
              link_icon = TerminalLink.link(item["url"], " » ")
              repo_info = " (#{item["repository"]})" if item["repository"]
              content << "- #{item["title"]}#{repo_info} #{link_icon}"
            elsif item["summary"]
              # Jira ticket with clickable link icon
              link_icon = TerminalLink.link(item["url"], " » ")
              content << "- #{item["key"]}: #{item["summary"]} #{link_icon}"
            end
          end
          content << ""
        end

        content.join("\n")
      end
    end
  end
end
