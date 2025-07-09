require "spec_helper"

RSpec.describe SelfReview::Commands::Setup do
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

  it "prompts for GitHub token" do
    allow($stdin).to receive(:gets).and_return("github_token_123\n", "\n")
    expect { subject.call }.to output(/GitHub personal access token/).to_stdout
  end

  it "prompts for Jira configuration" do
    allow($stdin).to receive(:gets).and_return("\n", "https://company.atlassian.net\n", "user@example.com\n", "jira_token_456\n")
    expect { subject.call }.to output(/Jira URL/).to_stdout
  end

  it "saves configuration to file" do
    allow($stdin).to receive(:gets).and_return("github_token_123\n", "\n")

    expect(SelfReview::Config).to receive(:save).with(hash_including("github_token" => "github_token_123"))
    subject.call
  end
end
