require "spec_helper"

RSpec.describe SelfReview::JiraClient do
  describe ".fetch_done_tickets" do
    let(:url) { "https://test.atlassian.net" }
    let(:username) { "test@example.com" }
    let(:token) { "test_jira_token" }
    let(:since_date) { Date.new(2024, 1, 1) }
    let(:end_date) { Date.new(2024, 1, 31) }

    let(:mock_http) { double("Net::HTTP") }
    let(:mock_response) { double("Net::HTTPResponse") }

    before do
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)
    end

    context "when API call succeeds" do
      let(:jira_response_body) do
        {
          "issues" => [
            {
              "key" => "PROJ-123",
              "fields" => {
                "summary" => "Implement user authentication",
                "status" => {"name" => "Done"},
                "updated" => "2024-01-15T10:30:00.000+0000",
                "description" => "Add OAuth login system",
                "priority" => {"name" => "High"},
                "issuetype" => {"name" => "Story"}
              }
            },
            {
              "key" => "PROJ-124",
              "fields" => {
                "summary" => "Fix database performance",
                "status" => {"name" => "Done"},
                "updated" => "2024-01-10T14:20:00.000+0000",
                "description" => nil,
                "priority" => nil,
                "issuetype" => {"name" => "Bug"}
              }
            }
          ]
        }.to_json
      end

      before do
        allow(mock_response).to receive(:code).and_return("200")
        allow(mock_response).to receive(:body).and_return(jira_response_body)
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it "returns formatted ticket data" do
        tickets = described_class.fetch_done_tickets(url, username, token, since_date, end_date)

        expect(tickets.length).to eq(2)

        first_ticket = tickets[0]
        expect(first_ticket[:key]).to eq("PROJ-123")
        expect(first_ticket[:summary]).to eq("Implement user authentication")
        expect(first_ticket[:status]).to eq("Done")
        expect(first_ticket[:updated]).to eq("2024-01-15")
        expect(first_ticket[:description]).to eq("Add OAuth login system")
        expect(first_ticket[:priority]).to eq("High")
        expect(first_ticket[:issue_type]).to eq("Story")
        expect(first_ticket[:url]).to eq("https://test.atlassian.net/browse/PROJ-123")

        second_ticket = tickets[1]
        expect(second_ticket[:key]).to eq("PROJ-124")
        expect(second_ticket[:description]).to eq("")
        expect(second_ticket[:priority]).to eq("None")
      end

      it "sorts tickets by updated date, most recent first" do
        tickets = described_class.fetch_done_tickets(url, username, token, since_date, end_date)

        expect(tickets[0][:updated]).to eq("2024-01-15") # More recent
        expect(tickets[1][:updated]).to eq("2024-01-10") # Older
      end

      it "constructs correct JQL query" do
        expected_jql = "assignee = currentUser() AND status = Done AND updated >= '2024-01-01' AND updated <= '2024-01-31'"

        # Override the existing mock to capture the request details
        expect(mock_http).to receive(:request) do |request|
          expect(request.uri.query).to include(CGI.escape(expected_jql))
          expect(request.uri.query).to include("fields=key%2Csummary%2Cstatus%2Cupdated%2Cdescription%2Cassignee%2Cpriority%2Cissuetype")
          expect(request.uri.query).to include("maxResults=100")
          expect(request.uri.hostname).to eq("test.atlassian.net")
          expect(request.uri.port).to eq(443)
          expect(request.uri.scheme).to eq("https")
        end.and_return(mock_response)

        described_class.fetch_done_tickets(url, username, token, since_date, end_date)
      end

      it "sets correct authorization header" do
        expected_auth = Base64.strict_encode64("#{username}:#{token}")

        expect(mock_http).to receive(:request) do |request|
          expect(request["Authorization"]).to eq("Basic #{expected_auth}")
          expect(request["Accept"]).to eq("application/json")
        end.and_return(mock_response)

        described_class.fetch_done_tickets(url, username, token, since_date, end_date)
      end
    end

    context "with default date parameters" do
      before do
        allow(Date).to receive(:today).and_return(Date.new(2024, 1, 31))
        allow(mock_response).to receive(:code).and_return("200")
        allow(mock_response).to receive(:body).and_return('{"issues": []}')
      end

      it "uses default date range when not provided" do
        expected_jql = "assignee = currentUser() AND status = Done AND updated >= '2024-01-01' AND updated <= '2024-01-31'"

        expect(mock_http).to receive(:request) do |request|
          expect(request.uri.query).to include(CGI.escape(expected_jql))
        end.and_return(mock_response)

        tickets = described_class.fetch_done_tickets(url, username, token)
        expect(tickets).to eq([])
      end
    end

    context "when API returns error status" do
      before do
        allow(mock_response).to receive(:code).and_return("401")
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it "handles HTTP error status gracefully" do
        expect {
          tickets = described_class.fetch_done_tickets(url, username, token, since_date, end_date)
          expect(tickets).to eq([])
        }.to output(/Jira API error: HTTP 401/).to_stdout
      end
    end

    context "when API returns invalid JSON" do
      before do
        allow(mock_response).to receive(:code).and_return("200")
        allow(mock_response).to receive(:body).and_return("Invalid JSON")
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it "handles JSON parsing errors gracefully" do
        expect {
          tickets = described_class.fetch_done_tickets(url, username, token, since_date, end_date)
          expect(tickets).to eq([])
        }.to output(/Jira API error: Invalid JSON response/).to_stdout
      end
    end

    context "when network error occurs" do
      before do
        allow(Net::HTTP).to receive(:start).and_raise(StandardError.new("Network timeout"))
      end

      it "handles network errors gracefully" do
        expect {
          tickets = described_class.fetch_done_tickets(url, username, token, since_date, end_date)
          expect(tickets).to eq([])
        }.to output(/Error fetching Jira data: Network timeout/).to_stdout
      end
    end

    context "with verbose logging" do
      before do
        allow(mock_response).to receive(:code).and_return("200")
        allow(mock_response).to receive(:body).and_return('{"issues": []}')
        allow(mock_http).to receive(:request).and_return(mock_response)
      end

      it "outputs verbose logging when enabled" do
        expect {
          described_class.fetch_done_tickets(url, username, token, since_date, end_date, verbose: true)
        }.to output(/Jira API: Using JQL query.*Jira API: Requesting URL.*Jira API: Response code.*Jira API: Found 0 tickets/m).to_stdout
      end

      it "does not output verbose logging when disabled" do
        expect {
          described_class.fetch_done_tickets(url, username, token, since_date, end_date, verbose: false)
        }.not_to output(/Jira API:/).to_stdout
      end
    end
  end
end
