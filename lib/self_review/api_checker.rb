require "net/http"
require "uri"
require "json"
require "base64"
require "timeout"

module SelfReview
  class ApiChecker
    def self.check_github(token, verbose: false)
      return {status: :missing, message: "No GitHub token configured"} if token.nil? || token.empty?

      begin
        if verbose
          puts Rainbow("GitHub API: Testing connection...").yellow
        end

        client = Octokit::Client.new(access_token: token)
        user = client.user

        if verbose
          puts Rainbow("GitHub API: Successfully authenticated as #{user.login}").yellow
        end

        {status: :success, message: "Connected as #{user.login}"}
      rescue Octokit::Unauthorized
        {status: :error, message: "Unauthorized - check your token"}
      rescue Octokit::TooManyRequests
        {status: :error, message: "Rate limited - try again later"}
      rescue Octokit::Error => e
        {status: :error, message: "GitHub API error: #{e.message}"}
      rescue => e
        {status: :error, message: "Connection error: #{e.message}"}
      end
    end

    def self.check_jira(url, username, token, verbose: false)
      return {status: :missing, message: "No Jira configuration found"} if url.nil? || url.empty?

      begin
        uri = URI.join(url, "/rest/api/2/myself")

        if verbose
          puts Rainbow("Jira API: Testing connection to #{uri}").yellow
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

        case response.code
        when "200"
          user_data = JSON.parse(response.body)

          if verbose
            puts Rainbow("Jira API: Successfully authenticated as #{user_data["displayName"]}").yellow
          end

          {status: :success, message: "Connected as #{user_data["displayName"]}"}
        when "401"
          {status: :error, message: "Unauthorized - check your credentials"}
        when "403"
          {status: :error, message: "Forbidden - check your permissions"}
        else
          {status: :error, message: "HTTP #{response.code}: #{response.message}"}
        end
      rescue Net::TimeoutError
        {status: :error, message: "Timeout - check your connection"}
      rescue Net::ConnectTimeout
        {status: :error, message: "Connection timeout - check your URL"}
      rescue JSON::ParserError
        {status: :error, message: "Invalid response from server"}
      rescue => e
        {status: :error, message: "Connection error: #{e.message}"}
      end
    end
  end
end
