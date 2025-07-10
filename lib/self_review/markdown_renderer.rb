require "rainbow"

module SelfReview
  class MarkdownRenderer
    class << self
      def render(markdown_content)
        lines = markdown_content.split("\n")
        output = []

        lines.each do |line|
          output << render_line(line)
        end

        output.join("\n")
      end

      private

      def render_line(line)
        case line
        when /^# (.+)$/
          # H1 headers - bold, bright, with underline
          title = $1
          Rainbow(title).bright.bold.underline
        when /^## (.+)$/
          # H2 headers - bold, cyan
          title = $1
          Rainbow(title).cyan.bold
        when /^### (.+)$/
          # H3 headers - bold, yellow
          title = $1
          Rainbow(title).yellow.bold
        when /^\*\*(.+):\*\*$/
          # Bold labels like "Items (7):"
          text = $1
          Rainbow("#{text}:").bold
        when /^- (.+)$/
          # Bullet points - add colored bullet
          text = $1
          "#{Rainbow("•").green} #{text}"
        when /^Generated: (.+)$/
          # Metadata lines - make them dim
          Rainbow(line).faint
        when /^Data period: (.+)$/
          Rainbow(line).faint
        when /^Total items analyzed: (.+)$/
          Rainbow(line).faint
        when line.strip.empty?
          # Empty lines
          ""
        else
          # Regular text
          line
        end
      end
    end
  end
end
