require "ruby_llm"

module SelfReview
  class LLMService
    class << self
      def cluster_work(github_prs, jira_tickets)
        work_items = format_work_items(github_prs, jira_tickets)

        prompt = build_clustering_prompt(work_items)

        begin
          response = client.ask("You are a helpful assistant that analyzes software development work and groups it into meaningful clusters.\n\n#{prompt}")

          parse_clustering_response(response.content, work_items.length)
        rescue => e
          puts Rainbow("Error clustering work: #{e.message}").red
          fallback_clustering(github_prs, jira_tickets)
        end
      end

      def summarize_accomplishments(clusters)
        prompt = build_summary_prompt(clusters)

        begin
          response = client.ask("You are a helpful assistant that summarizes technical accomplishments concisely.\n\n#{prompt}")

          parse_summary_response(response.content)
        rescue => e
          puts Rainbow("Error summarizing accomplishments: #{e.message}").red
          fallback_summary(clusters)
        end
      end

      def client
        @client ||= create_client
      end

      private

      def create_client
        config = Config.load

        # Configure RubyLLM with available API keys
        RubyLLM.configure do |llm_config|
          if config["anthropic_api_key"] && !config["anthropic_api_key"].empty?
            llm_config.anthropic_api_key = config["anthropic_api_key"]
          end
          if config["openai_api_key"] && !config["openai_api_key"].empty?
            llm_config.openai_api_key = config["openai_api_key"]
          end
        end

        # Try Anthropic Claude first
        if config["anthropic_api_key"] && !config["anthropic_api_key"].empty?
          RubyLLM.chat(provider: :anthropic, model: "claude-3-sonnet-20240229")
        # Fall back to OpenAI GPT
        elsif config["openai_api_key"] && !config["openai_api_key"].empty?
          RubyLLM.chat(provider: :openai, model: "gpt-4-turbo-preview")
        else
          raise "No LLM API keys configured. Run 'self-review setup' to configure."
        end
      end

      def format_work_items(github_prs, jira_tickets)
        items = []

        github_prs.each do |pr|
          items << {
            type: "GitHub PR",
            title: pr[:title],
            description: pr[:body] || "",
            url: pr[:url],
            date: pr[:merged_at]
          }
        end

        jira_tickets.each do |ticket|
          items << {
            type: "Jira Ticket",
            title: "#{ticket[:key]}: #{ticket[:summary]}",
            description: ticket[:description] || "",
            url: ticket[:url],
            date: ticket[:updated]
          }
        end

        items
      end

      def build_clustering_prompt(work_items)
        items_text = work_items.map.with_index(1) do |item, index|
          "#{index}. #{item[:type]}: #{item[:title]}\n   Description: #{item[:description].strip[0..200]}..."
        end.join("\n\n")

        <<~PROMPT
          Please analyze the following work items and group them into 3-5 meaningful clusters based on themes, projects, or types of work:

          #{items_text}

          For each cluster, provide:
          1. A descriptive name for the cluster
          2. A brief description of what the cluster represents
          3. The numbers of the work items that belong to this cluster

          Format your response as JSON with this structure:
          {
            "clusters": [
              {
                "name": "Cluster Name",
                "description": "Brief description of the cluster",
                "item_numbers": [1, 3, 5]
              }
            ]
          }
        PROMPT
      end

      def build_summary_prompt(clusters)
        clusters_text = clusters.map do |cluster|
          "- #{cluster[:name]}: #{cluster[:description]} (#{cluster[:items].length} items)"
        end.join("\n")

        <<~PROMPT
          Based on these work clusters, create a concise bullet-point summary of accomplishments:

          #{clusters_text}

          Create 3-5 bullet points that highlight key accomplishments and impact. Focus on:
          - What was built or improved
          - Problems solved
          - Value delivered

          Format as a simple markdown list with bullet points.
        PROMPT
      end

      def parse_clustering_response(response, total_items)
        json_response = JSON.parse(response)
        json_response["clusters"].map do |cluster|
          {
            name: cluster["name"],
            description: cluster["description"],
            item_numbers: cluster["item_numbers"]
          }
        end
      rescue JSON::ParserError
        # If JSON parsing fails, create a single cluster with all items
        [{
          name: "General Work",
          description: "Mixed development tasks and improvements",
          item_numbers: (1..total_items).to_a
        }]
      end

      def parse_summary_response(response)
        # Extract bullet points from the response
        lines = response.split("\n").select do |line|
          line.strip.start_with?("- ", "* ", "• ") || line.strip.match(/^\d+\./)
        end

        lines.map { |line| line.strip.sub(/^[-*•]\s*/, "").sub(/^\d+\.\s*/, "") }
      end

      def fallback_clustering(github_prs, jira_tickets)
        clusters = []

        if github_prs.length > 0
          clusters << {
            name: "GitHub Development",
            description: "Pull requests and code changes",
            item_numbers: (1..github_prs.length).to_a
          }
        end

        if jira_tickets.length > 0
          start_num = github_prs.length + 1
          clusters << {
            name: "Jira Tasks",
            description: "Completed tickets and tasks",
            item_numbers: (start_num..start_num + jira_tickets.length - 1).to_a
          }
        end

        clusters
      end

      def fallback_summary(clusters)
        [
          "Completed #{clusters.map { |c| c[:items]&.length || 0 }.sum} work items across multiple areas",
          "Made progress on software development and task completion",
          "Delivered features and fixes to improve system functionality"
        ]
      end
    end
  end
end
