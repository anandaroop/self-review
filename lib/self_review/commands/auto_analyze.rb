module SelfReview
  module Commands
    class AutoAnalyze < Dry::CLI::Command
      desc "Fetch and analyze work for a given date range"
      argument :date_range, required: true, desc: "Natural language date range (e.g., 'last 3 months', 'q2 of this year')"
      option :verbose, type: :boolean, default: false, desc: "Enable verbose output for all operations"

      def call(date_range:, verbose: false, **)
        puts Rainbow("🚀 Running fetch + analyze for: #{date_range}").bright.blue
        puts

        # Step 1: Fetch the data
        fetch_command = Commands::Fetch.new
        fetch_command.call(date_range: date_range, verbose: verbose)

        puts
        puts Rainbow("=" * 50).bright.cyan

        # Step 2: Analyze the data
        analyze_command = Commands::Analyze.new
        analyze_command.call(verbose: verbose)
      end
    end
  end
end
