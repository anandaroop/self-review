require "octokit"
require "date"

module SelfReview
  class GitHubClient
    def self.fetch_merged_prs(token, since_date = nil)
      since_date ||= Date.today - 30 # Default to 1 month ago

      client = Octokit::Client.new(access_token: token)
      user = client.user

      # Search for PRs authored by the user that were merged since the date
      query = "author:#{user.login} is:pr is:merged merged:>=#{since_date.strftime("%Y-%m-%d")}"

      results = client.search_issues(query, per_page: 100)

      prs = results.items.map do |pr|
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
