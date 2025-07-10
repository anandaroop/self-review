require "spec_helper"

RSpec.describe SelfReview::GitHubClient do
  describe ".fetch_merged_prs" do
    let(:token) { "test_github_token" }
    let(:since_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 1, 31) }
    let(:mock_client) { double("Octokit::Client") }
    let(:mock_user) { double("User", login: "testuser") }

    before do
      allow(Octokit::Client).to receive(:new).with(access_token: token).and_return(mock_client)
      allow(mock_client).to receive(:user).and_return(mock_user)
    end

    context "when API call succeeds" do
      let(:search_results) do
        double("SearchResults",
          items: [
            double("PR",
              title: "Add user authentication",
              html_url: "https://github.com/test/repo/pull/1",
              repository_url: "https://api.github.com/repos/test/repo",
              body: "Implement OAuth login system",
              pull_request: double("PullRequest", merged_at: Time.new(2024, 1, 15, 12, 0, 0))),
            double("PR",
              title: "Fix login bug",
              html_url: "https://github.com/test/repo/pull/2",
              repository_url: "https://api.github.com/repos/test/repo",
              body: nil,
              pull_request: double("PullRequest", merged_at: Time.new(2024, 1, 10, 9, 30, 0)))
          ])
      end

      before do
        expected_query = "author:testuser is:pr is:merged merged:2024-01-01..2024-01-31"
        allow(mock_client).to receive(:search_issues).with(expected_query, per_page: 100).and_return(search_results)
      end

      it "returns formatted PR data" do
        prs = described_class.fetch_merged_prs(token, since_date, end_date)

        expect(prs.length).to eq(2)

        first_pr = prs[0]
        expect(first_pr[:title]).to eq("Add user authentication")
        expect(first_pr[:url]).to eq("https://github.com/test/repo/pull/1")
        expect(first_pr[:repository]).to eq("test/repo")
        expect(first_pr[:merged_at]).to eq("2024-01-15")
        expect(first_pr[:body]).to eq("Implement OAuth login system")

        second_pr = prs[1]
        expect(second_pr[:title]).to eq("Fix login bug")
        expect(second_pr[:merged_at]).to eq("2024-01-10")
        expect(second_pr[:body]).to eq("")
      end

      it "sorts PRs by merged date, most recent first" do
        prs = described_class.fetch_merged_prs(token, since_date, end_date)

        expect(prs[0][:merged_at]).to eq("2024-01-15") # More recent
        expect(prs[1][:merged_at]).to eq("2024-01-10") # Older
      end

      it "constructs correct search query" do
        expected_query = "author:testuser is:pr is:merged merged:2024-01-01..2024-01-31"
        expect(mock_client).to receive(:search_issues).with(expected_query, per_page: 100).and_return(search_results)

        described_class.fetch_merged_prs(token, since_date, end_date)
      end

      it "extracts repository name from repository_url" do
        prs = described_class.fetch_merged_prs(token, since_date, end_date)
        expect(prs[0][:repository]).to eq("test/repo")
      end
    end

    context "with default date parameters" do
      before do
        allow(Date).to receive(:today).and_return(Date.new(2024, 1, 31))
        expected_query = "author:testuser is:pr is:merged merged:2024-01-01..2024-01-31"
        allow(mock_client).to receive(:search_issues).with(expected_query, per_page: 100).and_return(double("SearchResults", items: []))
      end

      it "uses default date range when not provided" do
        prs = described_class.fetch_merged_prs(token)
        expect(prs).to eq([])
      end
    end

    context "when Octokit raises an error" do
      before do
        allow(mock_client).to receive(:search_issues).and_raise(Octokit::Unauthorized.new)
      end

      it "handles Octokit errors gracefully" do
        expect {
          prs = described_class.fetch_merged_prs(token, since_date, end_date)
          expect(prs).to eq([])
        }.to output(/GitHub API error/).to_stdout
      end
    end

    context "when a generic error occurs" do
      before do
        allow(mock_client).to receive(:search_issues).and_raise(StandardError.new("Network error"))
      end

      it "handles generic errors gracefully" do
        expect {
          prs = described_class.fetch_merged_prs(token, since_date, end_date)
          expect(prs).to eq([])
        }.to output(/Error fetching GitHub data/).to_stdout
      end
    end

    context "with verbose logging" do
      before do
        allow(mock_client).to receive(:search_issues).and_return(double("SearchResults", items: []))
      end

      it "outputs verbose logging when enabled" do
        expect {
          described_class.fetch_merged_prs(token, since_date, end_date, verbose: true)
        }.to output(/GitHub API: Fetching user info.*GitHub API: Searching with query.*GitHub API: Found 0 PRs/m).to_stdout
      end

      it "does not output verbose logging when disabled" do
        expect {
          described_class.fetch_merged_prs(token, since_date, end_date, verbose: false)
        }.not_to output(/GitHub API:/).to_stdout
      end
    end
  end
end
