module SelfReview
  module Commands
    class Help < Dry::CLI::Command
      desc "Display help information"

      def call(**)
        puts Rainbow("self-review").bright.blue
        puts
        puts "Usage: self-review [COMMAND|DATE_RANGE]"
        puts
        puts Rainbow("Commands:").bright
        puts "  help     Display this help message"
        puts "  setup    Configure API credentials"
        puts "  check    Check API connectivity"
        puts "  fetch    Fetch recent work from GitHub and Jira"
        puts "  analyze  Analyze recent work and generate summary"
        puts
        puts Rainbow("Quick Analysis:").bright
        puts "  \"DATE_RANGE\"  Fetch and analyze in one step (e.g., \"last 3 months\")"
        puts
        puts Rainbow("Examples:").bright
        puts "  self-review help"
        puts "  self-review setup"
        puts "  self-review check"
        puts "  self-review fetch --since=2024-01-01"
        puts "  self-review fetch \"last 3 months\""
        puts "  self-review analyze"
        puts "  self-review analyze --display analysis-250709-224154.md"
        puts
        puts Rainbow("Quick Examples:").bright
        puts "  self-review \"last 3 months\""
        puts "  self-review \"q2 of this year\""
        puts "  self-review \"first half of 2025\""
        puts
        puts Rainbow("For more information, visit:").bright
        puts "https://github.com/username/self-review"
      end
    end
  end
end
