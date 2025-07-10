require "spec_helper"

RSpec.describe SelfReview::LLMService do
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

  describe ".cluster_work" do
    let(:github_prs) do
      [
        {"title" => "Add user authentication", "body" => "Implement OAuth login", "url" => "https://github.com/test/repo/pull/1", "merged_at" => "2024-01-10"},
        {"title" => "Fix login bug", "body" => "Resolve session timeout issue", "url" => "https://github.com/test/repo/pull/2", "merged_at" => "2024-01-12"}
      ]
    end

    let(:jira_tickets) do
      [
        {"key" => "PROJ-123", "summary" => "Database optimization", "description" => "Improve query performance", "url" => "https://jira.test.com/PROJ-123", "updated" => "2024-01-11"}
      ]
    end

    let(:mock_llm_client) { double("LLM Client") }
    let(:mock_response) { double("Response", content: clustering_response_json) }

    let(:clustering_response_json) do
      {
        "clusters" => [
          {
            "name" => "Authentication & Security",
            "description" => "User authentication and security improvements",
            "item_numbers" => [1, 2]
          },
          {
            "name" => "Performance Optimization",
            "description" => "Database and performance improvements",
            "item_numbers" => [3]
          }
        ]
      }.to_json
    end

    before do
      SelfReview::Config.save({"anthropic_api_key" => "test_key"})
      allow(described_class).to receive(:client).and_return(mock_llm_client)
    end

    context "when LLM responds with valid JSON" do
      before do
        allow(mock_llm_client).to receive(:ask).and_return(mock_response)
      end

      it "returns parsed clusters" do
        clusters = described_class.cluster_work(github_prs, jira_tickets)

        expect(clusters.length).to eq(2)
        expect(clusters[0][:name]).to eq("Authentication & Security")
        expect(clusters[0][:description]).to eq("User authentication and security improvements")
        expect(clusters[0][:item_numbers]).to eq([1, 2])
        expect(clusters[1][:name]).to eq("Performance Optimization")
        expect(clusters[1][:item_numbers]).to eq([3])
      end

      it "sends properly formatted work items to LLM" do
        expected_prompt = /1\. GitHub PR: Add user authentication.*2\. GitHub PR: Fix login bug.*3\. Jira Ticket: PROJ-123: Database optimization/m

        expect(mock_llm_client).to receive(:ask) do |prompt|
          expect(prompt).to match(expected_prompt)
          mock_response
        end

        described_class.cluster_work(github_prs, jira_tickets)
      end
    end

    context "when LLM responds with invalid JSON" do
      before do
        allow(mock_llm_client).to receive(:ask).and_return(double("Response", content: "Invalid JSON response"))
      end

      it "returns fallback clustering" do
        clusters = described_class.cluster_work(github_prs, jira_tickets)

        expect(clusters.length).to eq(1)
        expect(clusters[0][:name]).to eq("General Work")
        expect(clusters[0][:description]).to eq("Mixed development tasks and improvements")
        expect(clusters[0][:item_numbers]).to eq([1, 2, 3])
      end
    end

    context "when LLM request fails" do
      before do
        allow(mock_llm_client).to receive(:ask).and_raise(StandardError.new("API Error"))
      end

      it "returns fallback clustering with separate GitHub and Jira clusters" do
        clusters = described_class.cluster_work(github_prs, jira_tickets)

        expect(clusters.length).to eq(2)
        expect(clusters[0][:name]).to eq("GitHub Development")
        expect(clusters[0][:item_numbers]).to eq([1, 2])
        expect(clusters[1][:name]).to eq("Jira Tasks")
        expect(clusters[1][:item_numbers]).to eq([3])
      end
    end
  end

  describe ".summarize_accomplishments" do
    let(:clusters) do
      [
        {
          name: "Authentication & Security",
          description: "User authentication and security improvements",
          items: [{"title" => "Add OAuth"}, {"title" => "Fix login bug"}]
        },
        {
          name: "Performance Optimization",
          description: "Database and performance improvements",
          items: [{"key" => "PROJ-123", "summary" => "Database optimization"}]
        }
      ]
    end

    let(:mock_llm_client) { double("LLM Client") }
    let(:mock_response) { double("Response", content: summary_response) }

    let(:summary_response) do
      "- Implemented comprehensive user authentication system with OAuth integration\n" \
      "- Fixed critical login session timeout bugs affecting user experience\n" \
      "- Optimized database queries resulting in improved application performance"
    end

    before do
      SelfReview::Config.save({"anthropic_api_key" => "test_key"})
      allow(described_class).to receive(:client).and_return(mock_llm_client)
    end

    context "when LLM responds successfully" do
      before do
        allow(mock_llm_client).to receive(:ask).and_return(mock_response)
      end

      it "returns parsed accomplishments" do
        accomplishments = described_class.summarize_accomplishments(clusters)

        expect(accomplishments.length).to eq(3)
        expect(accomplishments[0]).to eq("Implemented comprehensive user authentication system with OAuth integration")
        expect(accomplishments[1]).to eq("Fixed critical login session timeout bugs affecting user experience")
        expect(accomplishments[2]).to eq("Optimized database queries resulting in improved application performance")
      end

      it "sends cluster information to LLM" do
        expected_prompt = /Authentication & Security.*Performance Optimization/m

        expect(mock_llm_client).to receive(:ask) do |prompt|
          expect(prompt).to match(expected_prompt)
          mock_response
        end

        described_class.summarize_accomplishments(clusters)
      end
    end

    context "when LLM request fails" do
      before do
        allow(mock_llm_client).to receive(:ask).and_raise(StandardError.new("API Error"))
      end

      it "returns fallback summary" do
        accomplishments = described_class.summarize_accomplishments(clusters)

        expect(accomplishments.length).to eq(3)
        expect(accomplishments[0]).to include("Completed")
        expect(accomplishments[1]).to eq("Made progress on software development and task completion")
        expect(accomplishments[2]).to eq("Delivered features and fixes to improve system functionality")
      end
    end
  end

  describe ".client" do
    context "when Anthropic API key is configured" do
      before do
        SelfReview::Config.save({"anthropic_api_key" => "test_anthropic_key"})
      end

      it "creates Anthropic client" do
        expect(RubyLLM).to receive(:chat).with(provider: :anthropic, model: "claude-3-sonnet-20240229")
        described_class.client
      end
    end

    context "when OpenAI API key is configured" do
      before do
        SelfReview::Config.save({"openai_api_key" => "test_openai_key"})
      end

      it "creates OpenAI client" do
        expect(RubyLLM).to receive(:chat).with(provider: :openai, model: "gpt-4-turbo-preview")
        described_class.client
      end
    end

    context "when no API keys are configured" do
      before do
        SelfReview::Config.save({})
      end

      it "raises an error" do
        expect { described_class.client }.to raise_error(/No LLM API keys configured/)
      end
    end
  end
end
