require "spec_helper"

RSpec.describe SelfReview::Commands::Check do
  let(:config_dir) { "/tmp/self_review_test" }
  let(:config_file) { "#{config_dir}/config.yml" }

  before do
    FileUtils.mkdir_p(config_dir)
    allow(SelfReview::Config).to receive(:config_dir).and_return(config_dir)
    allow(SelfReview::Config).to receive(:config_file).and_return(config_file)
  end

  after do
    FileUtils.rm_rf(config_dir)
  end

  context "when no credentials are configured" do
    before do
      SelfReview::Config.save({})
    end

    it "shows API status even without credentials" do
      expect { subject.call }.to output(/No credentials configured/).to_stdout
    end
  end

  context "when GitHub credentials are configured" do
    before do
      SelfReview::Config.save({"github_token" => "test_token"})
    end

    it "tests GitHub API connectivity" do
      allow(SelfReview::ApiChecker).to receive(:check_github).and_return({status: :success, message: "Connected as testuser"})
      expect { subject.call }.to output(/1\/1 APIs are working correctly/).to_stdout
    end

    it "handles GitHub API errors gracefully" do
      allow(SelfReview::ApiChecker).to receive(:check_github).and_return({status: :error, message: "Unauthorized - check your token"})
      expect { subject.call }.to output(/0\/1 APIs are accessible/).to_stdout
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

    it "tests Jira API connectivity" do
      allow(SelfReview::ApiChecker).to receive(:check_jira).and_return({status: :success, message: "Connected as Test User"})
      expect { subject.call }.to output(/1\/1 APIs are working correctly/).to_stdout
    end

    it "handles Jira API errors gracefully" do
      allow(SelfReview::ApiChecker).to receive(:check_jira).and_return({status: :error, message: "Timeout - check your connection"})
      expect { subject.call }.to output(/0\/1 APIs are accessible/).to_stdout
    end
  end
end
