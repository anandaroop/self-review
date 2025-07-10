require "spec_helper"

RSpec.describe SelfReview::DateParser do
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

  describe ".parse" do
    let(:mock_llm_client) { double("LLM Client") }

    before do
      SelfReview::Config.save({"anthropic_api_key" => "test_key"})
      allow(SelfReview::LLMService).to receive(:client).and_return(mock_llm_client)
      # Freeze time to make tests predictable
      allow(Date).to receive(:today).and_return(Date.new(2024, 6, 15))
    end

    context "with explicit YYYY-MM-DD format" do
      it "parses valid date directly without LLM" do
        expect(SelfReview::LLMService).not_to receive(:client)

        result = described_class.parse("2024-01-15")

        expect(result[:start_date]).to eq(Date.new(2024, 1, 15))
        expect(result[:end_date]).to eq(Date.new(2024, 6, 15)) # today
        expect(result[:source]).to eq("explicit_date")
        expect(result[:confidence]).to eq("high")
      end

      it "raises error for invalid date format" do
        expect { described_class.parse("2024-13-45") }.to raise_error(SelfReview::DateParser::ParseError, /Invalid date format/)
      end
    end

    context "with natural language input" do
      let(:llm_response_json) do
        {
          "start_date" => "2024-03-15",
          "end_date" => "2024-06-15",
          "confidence" => "high",
          "explanation" => "Interpreted as the last 3 months from current date"
        }.to_json
      end

      let(:mock_response) { double("Response", content: llm_response_json) }

      context "when LLM parses successfully" do
        before do
          allow(mock_llm_client).to receive(:ask).and_return(mock_response)
        end

        it "returns parsed date range from LLM" do
          result = described_class.parse("last 3 months")

          expect(result[:start_date]).to eq(Date.new(2024, 3, 15))
          expect(result[:end_date]).to eq(Date.new(2024, 6, 15))
          expect(result[:source]).to eq("llm_parsed")
          expect(result[:confidence]).to eq("high")
          expect(result[:explanation]).to eq("Interpreted as the last 3 months from current date")
        end

        it "sends proper context to LLM" do
          expected_prompt = /Current date: 2024-06-15.*Input: "q2 of this year"/m

          expect(mock_llm_client).to receive(:ask) do |prompt|
            expect(prompt).to match(expected_prompt)
            expect(prompt).to include("Q2 (Apr-Jun)")
            mock_response
          end

          described_class.parse("q2 of this year")
        end

        it "falls back when date range order is invalid" do
          invalid_response = {
            "start_date" => "2024-06-15",
            "end_date" => "2024-03-15",
            "confidence" => "high",
            "explanation" => "Invalid range"
          }.to_json

          invalid_mock_response = double("Response", content: invalid_response)
          allow(mock_llm_client).to receive(:ask).and_return(invalid_mock_response)

          result = described_class.parse("invalid range")
          expect(result[:source]).to eq("fallback_default") # Falls back to default
        end
      end

      context "when LLM returns invalid JSON" do
        it "falls back to default parsing" do
          invalid_json_response = double("Response", content: "Invalid JSON")
          allow(mock_llm_client).to receive(:ask).and_return(invalid_json_response)

          result = described_class.parse("some natural language")
          expect(result[:source]).to eq("fallback_default") # Falls back to default
        end
      end

      context "when LLM request fails" do
        before do
          allow(mock_llm_client).to receive(:ask).and_raise(StandardError.new("API Error"))
        end

        it "falls back to regex parsing for 'last X months'" do
          result = described_class.parse("last 3 months")

          expect(result[:start_date]).to eq(Date.new(2024, 3, 15)) # 3 months back from June 15
          expect(result[:end_date]).to eq(Date.new(2024, 6, 15))
          expect(result[:source]).to eq("fallback_regex")
          expect(result[:confidence]).to eq("medium")
        end

        it "falls back to regex parsing for 'this year'" do
          result = described_class.parse("this year")

          expect(result[:start_date]).to eq(Date.new(2024, 1, 1))
          expect(result[:end_date]).to eq(Date.new(2024, 6, 15))
          expect(result[:source]).to eq("fallback_regex")
          expect(result[:confidence]).to eq("high")
        end

        it "falls back to default range for unrecognized input" do
          result = described_class.parse("some random text")

          expect(result[:start_date]).to eq(Date.new(2024, 5, 15)) # 1 month back
          expect(result[:end_date]).to eq(Date.new(2024, 6, 15))
          expect(result[:source]).to eq("fallback_default")
          expect(result[:confidence]).to eq("low")
        end
      end
    end

    context "with various natural language patterns" do
      let(:llm_response_json) do
        {
          "start_date" => "2024-01-01",
          "end_date" => "2024-06-15",
          "confidence" => "high",
          "explanation" => "Test explanation"
        }.to_json
      end

      let(:mock_response) { double("Response", content: llm_response_json) }

      before do
        allow(mock_llm_client).to receive(:ask).and_return(mock_response)
      end

      [
        "last 3 months",
        "q2 of this year",
        "first half of 2024",
        "second half of 2023",
        "this quarter",
        "last quarter"
      ].each do |input|
        it "handles '#{input}' with LLM parsing" do
          result = described_class.parse(input)
          expect(result[:source]).to eq("llm_parsed")
        end
      end
    end
  end
end
