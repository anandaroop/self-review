require "spec_helper"

RSpec.describe SelfReview::Commands::Fetch do
  let(:config_dir) { "/tmp/self_review_test" }
  let(:config_file) { "#{config_dir}/config.yml" }

  before do
    FileUtils.mkdir_p(config_dir)
    allow(SelfReview::Config).to receive(:config_dir).and_return(config_dir)
    allow(SelfReview::Config).to receive(:config_file).and_return(config_file)
    allow(Time).to receive(:now).and_return(Time.new(2024, 1, 15, 10, 30, 45))
  end

  after do
    FileUtils.rm_rf(config_dir)
  end

  context "when no credentials are configured" do
    before do
      SelfReview::Config.save({})
    end

    it "reports that no credentials are configured" do
      expect { subject.call }.to output(/No credentials configured/).to_stdout
    end
  end

  context "when GitHub credentials are configured" do
    before do
      SelfReview::Config.save({"github_token" => "test_token"})
    end

    it "fetches GitHub PRs and creates YAML file" do
      allow(SelfReview::GitHubClient).to receive(:fetch_merged_prs).and_return([
        {title: "Add user authentication", url: "https://github.com/test/repo/pull/1", merged_at: "2024-01-10"}
      ])
      allow(SelfReview::JiraClient).to receive(:fetch_done_tickets).and_return([])

      expect { subject.call }.to output(/Fetching from GitHub/).to_stdout
      expect { subject.call }.to output(/recent-work-240115-103045\.yml/).to_stdout
    end

    it "handles date filtering with since parameter" do
      expect(SelfReview::GitHubClient).to receive(:fetch_merged_prs).with("test_token", Date.parse("2024-01-01")).and_return([])
      allow(SelfReview::JiraClient).to receive(:fetch_done_tickets).and_return([])
      subject.call(since: "2024-01-01")
    end
  end

  context "when Jira credentials are configured" do
    before do
      SelfReview::Config.save({
        "jira_url" => "https://test.atlassian.net",
        "jira_username" => "test@example.com",
        "jira_token" => "test_token"
      })
    end

    it "fetches Jira tickets and creates YAML file" do
      allow(SelfReview::JiraClient).to receive(:fetch_done_tickets).and_return([
        {key: "PROJ-123", summary: "Fix login bug", status: "Done", updated: "2024-01-12"}
      ])
      allow(SelfReview::GitHubClient).to receive(:fetch_merged_prs).and_return([])

      expect { subject.call }.to output(/Fetching from Jira/).to_stdout
      expect { subject.call }.to output(/recent-work-240115-103045\.yml/).to_stdout
    end
  end
end
