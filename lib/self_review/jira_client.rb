require "net/http"
require "uri"
require "json"
require "base64"
require "date"

module SelfReview
  class JiraClient
    def self.fetch_done_tickets(url, username, token, since_date = nil, verbose: false)
      since_date ||= Date.today - 30 # Default to 1 month ago

      # JQL query to find tickets assigned to the user that were marked Done since the date
      jql = "assignee = currentUser() AND status = Done AND updated >= '#{since_date.strftime("%Y-%m-%d")}'"

      if verbose
        puts Rainbow("Jira API: Using JQL query: #{jql}").yellow
      end

      uri = URI.join(url, "/rest/api/2/search")
      uri.query = URI.encode_www_form({
        jql: jql,
        fields: "key,summary,status,updated,description,assignee,priority,issuetype",
        maxResults: 100
      })

      if verbose
        puts Rainbow("Jira API: Requesting URL: #{uri}").yellow
      end

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Basic #{Base64.strict_encode64("#{username}:#{token}")}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      if verbose
        puts Rainbow("Jira API: Response code: #{response.code}").yellow
      end

      if response.code == "200"
        data = JSON.parse(response.body)

        if verbose
          puts Rainbow("Jira API: Found #{data["issues"].length} tickets").yellow
        end

        tickets = data["issues"].map do |issue|
          {
            key: issue["key"],
            summary: issue["fields"]["summary"],
            status: issue["fields"]["status"]["name"],
            updated: Date.parse(issue["fields"]["updated"]).strftime("%Y-%m-%d"),
            description: issue["fields"]["description"] || "",
            priority: issue["fields"]["priority"] ? issue["fields"]["priority"]["name"] : "None",
            issue_type: issue["fields"]["issuetype"]["name"],
            url: "#{url}/browse/#{issue["key"]}"
          }
        end

        # Sort by updated date, most recent first
        tickets.sort_by { |ticket| ticket[:updated] }.reverse
      else
        puts Rainbow("Jira API error: HTTP #{response.code}").red
        []
      end
    rescue JSON::ParserError
      puts Rainbow("Jira API error: Invalid JSON response").red
      []
    rescue => e
      puts Rainbow("Error fetching Jira data: #{e.message}").red
      []
    end
  end
end
