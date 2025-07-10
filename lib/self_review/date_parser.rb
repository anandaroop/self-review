require "json"
require "date"
require_relative "llm_service"

module SelfReview
  class DateParser
    class ParseError < StandardError; end

    class << self
      def parse(input, verbose: false)
        # If it's already in YYYY-MM-DD format, parse it directly
        if input.match?(/^\d{4}-\d{2}-\d{2}$/)
          begin
            date = Date.parse(input)
            return {
              start_date: date,
              end_date: Date.today,
              source: "explicit_date",
              confidence: "high"
            }
          rescue Date::Error
            raise ParseError, "Invalid date format: #{input}"
          end
        end

        # Use LLM to parse natural language
        parse_with_llm(input, verbose: verbose)
      end

      private

      def parse_with_llm(input, verbose: false)
        current_date = Date.today
        prompt = build_date_parsing_prompt(input, current_date)

        begin
          if verbose
            puts Rainbow("LLM: Parsing date range '#{input}' (current date: #{current_date})").yellow
          end

          response = LLMService.client(verbose: verbose).ask(prompt)

          if verbose
            puts Rainbow("LLM: Received date parsing response").yellow
          end

          parse_llm_response(response.content, input)
        rescue => e
          if verbose
            puts Rainbow("LLM date parsing failed: #{e.message}").red
          end
          fallback_parsing(input)
        end
      end

      def build_date_parsing_prompt(input, current_date)
        <<~PROMPT
          You are a date parsing assistant. Parse the following natural language date expression into a structured date range.

          Current date: #{current_date.strftime("%Y-%m-%d")} (#{current_date.strftime("%A, %B %d, %Y")})
          Input: "#{input}"

          Convert this to a date range suitable for querying work items. Consider:
          - The user wants to see work completed within this time period
          - For phrases like "last 3 months", calculate from the current date backwards
          - For quarters, use standard Q1 (Jan-Mar), Q2 (Apr-Jun), Q3 (Jul-Sep), Q4 (Oct-Dec)
          - For "this year" or "2025", use the full year
          - For "first half" or "second half", split the year accordingly

          Respond with JSON in this exact format:
          {
            "start_date": "YYYY-MM-DD",
            "end_date": "YYYY-MM-DD",
            "confidence": "high|medium|low",
            "explanation": "Brief explanation of how you interpreted the input"
          }

          If the input is ambiguous or unclear, use "low" confidence and make a reasonable assumption.
          Always ensure start_date is before or equal to end_date.
        PROMPT
      end

      def parse_llm_response(response, original_input)
        json_response = JSON.parse(response)

        start_date = Date.parse(json_response["start_date"])
        end_date = Date.parse(json_response["end_date"])
        confidence = json_response["confidence"]
        explanation = json_response["explanation"]

        # Validate the date range
        if start_date > end_date
          raise ParseError, "Invalid date range: start_date (#{start_date}) is after end_date (#{end_date})"
        end

        {
          start_date: start_date,
          end_date: end_date,
          source: "llm_parsed",
          confidence: confidence,
          explanation: explanation
        }
      rescue JSON::ParserError, Date::Error => e
        raise ParseError, "Failed to parse LLM response for '#{original_input}': #{e.message}"
      end

      def fallback_parsing(input)
        # Simple fallback for common patterns
        case input.downcase
        when /last (\d+) months?/
          months = $1.to_i
          end_date = Date.today
          start_date = end_date << months # Go back N months
          {
            start_date: start_date,
            end_date: end_date,
            source: "fallback_regex",
            confidence: "medium"
          }
        when /this year/
          current_year = Date.today.year
          {
            start_date: Date.new(current_year, 1, 1),
            end_date: Date.today,
            source: "fallback_regex",
            confidence: "high"
          }
        else
          # Default to last month if we can't parse anything
          end_date = Date.today
          start_date = end_date << 1
          {
            start_date: start_date,
            end_date: end_date,
            source: "fallback_default",
            confidence: "low"
          }
        end
      end
    end
  end
end
