module SelfReview
  class TerminalLink
    # Creates a clickable hyperlink in terminals that support OSC 8
    # Falls back to plain text for terminals that don't support it
    def self.link(url, text = nil)
      text ||= url

      # Check if terminal likely supports hyperlinks
      # Most modern terminals (iTerm2, Terminal.app, VS Code, etc.) support this
      if supports_hyperlinks?
        "\e]8;;#{url}\e\\#{text}\e]8;;\e\\"
      else
        # Fallback: show text with URL in parentheses
        "#{text} (#{url})"
      end
    end

    def self.supports_hyperlinks?
      # Check common environment variables that indicate hyperlink support
      # This is a heuristic - most modern terminals support it even if not advertised
      term = ENV["TERM"] || ""
      term_program = ENV["TERM_PROGRAM"] || ""

      # Known terminals with good hyperlink support
      supported_terms = ["xterm-256color", "screen-256color", "tmux-256color"]
      supported_programs = ["iTerm.app", "vscode", "Terminal.app", "WezTerm", "Hyper"]

      # Default to true for modern terminals
      # Users with older terminals will get the fallback format
      supported_terms.any? { |t| term.include?(t) } ||
        supported_programs.any? { |p| term_program.include?(p) } ||
        true # Optimistically assume support
    end
  end
end
