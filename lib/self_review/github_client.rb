require "octokit"
require "date"

module SelfReview
  class GitHubClient
    def self.fetch_merged_prs(token, since_date = nil, end_date = nil, verbose: false)
      since_date ||= Date.today - 30 # Default to 1 month ago
      end_date ||= Date.today

      client = Octokit::Client.new(access_token: token)
      user = client.user

      if verbose
        puts Rainbow("GitHub API: Fetching user info for #{user.login}").yellow
      end

      # Search for PRs authored by the user that were merged within the date range
      query = "author:#{user.login} is:pr is:merged merged:#{since_date.strftime("%Y-%m-%d")}..#{end_date.strftime("%Y-%m-%d")}"

      if verbose
        puts Rainbow("GitHub API: Searching with query: #{query}").yellow
      end

      # Fetch all pages of results
      all_items = []
      page = 1
      loop do
        results = client.search_issues(query, per_page: 100, page: page)
        all_items.concat(results.items)

        if verbose
          puts Rainbow("GitHub API: Page #{page} - fetched #{results.items.length} PRs (total so far: #{all_items.length})").yellow
        end

        # Check if there are more pages
        break unless results.items.length == 100
        page += 1
      end

      if verbose
        puts Rainbow("GitHub API: Found #{all_items.length} total PRs").yellow
      end

      prs = all_items.map do |pr|
        {
          title: pr.title,
          url: pr.html_url,
          repository: pr.repository_url.split("/").last(2).join("/"),
          merged_at: pr.pull_request.merged_at&.strftime("%Y-%m-%d"),
          body: pr.body || ""
        }
      end

      # Sort by merged date, most recent first
      prs.sort_by { |pr| pr[:merged_at] || "0000-00-00" }.reverse
    rescue Octokit::Error => e
      puts Rainbow("GitHub API error: #{e.message}").red
      []
    rescue => e
      puts Rainbow("Error fetching GitHub data: #{e.message}").red
      []
    end
  end
end
