require "spec_helper"

RSpec.describe SelfReview::TerminalLink do
  describe ".link" do
    let(:url) { "https://github.com/test/repo/pull/123" }
    let(:text) { "Test PR Title" }

    context "when terminal supports hyperlinks" do
      before do
        allow(described_class).to receive(:supports_hyperlinks?).and_return(true)
      end

      it "returns OSC 8 formatted hyperlink" do
        result = described_class.link(url, text)
        expect(result).to eq("\e]8;;#{url}\e\\#{text}\e]8;;\e\\")
      end

      it "uses URL as text when no text provided" do
        result = described_class.link(url)
        expect(result).to eq("\e]8;;#{url}\e\\#{url}\e]8;;\e\\")
      end
    end

    context "when terminal does not support hyperlinks" do
      before do
        allow(described_class).to receive(:supports_hyperlinks?).and_return(false)
      end

      it "returns text with URL in parentheses" do
        result = described_class.link(url, text)
        expect(result).to eq("#{text} (#{url})")
      end

      it "returns URL with itself in parentheses when no text provided" do
        result = described_class.link(url)
        expect(result).to eq("#{url} (#{url})")
      end
    end
  end

  describe ".supports_hyperlinks?" do
    context "with supported TERM values" do
      ["xterm-256color", "screen-256color", "tmux-256color"].each do |term|
        it "returns true for #{term}" do
          allow(ENV).to receive(:[]).with("TERM").and_return(term)
          allow(ENV).to receive(:[]).with("TERM_PROGRAM").and_return("")
          expect(described_class.supports_hyperlinks?).to be true
        end
      end
    end

    context "with supported TERM_PROGRAM values" do
      ["iTerm.app", "vscode", "Terminal.app", "WezTerm", "Hyper"].each do |program|
        it "returns true for #{program}" do
          allow(ENV).to receive(:[]).with("TERM").and_return("")
          allow(ENV).to receive(:[]).with("TERM_PROGRAM").and_return(program)
          expect(described_class.supports_hyperlinks?).to be true
        end
      end
    end

    context "with no recognized terminal" do
      before do
        allow(ENV).to receive(:[]).with("TERM").and_return("dumb")
        allow(ENV).to receive(:[]).with("TERM_PROGRAM").and_return("")
      end

      it "still returns true (optimistic default)" do
        expect(described_class.supports_hyperlinks?).to be true
      end
    end

    context "with nil environment variables" do
      before do
        allow(ENV).to receive(:[]).with("TERM").and_return(nil)
        allow(ENV).to receive(:[]).with("TERM_PROGRAM").and_return(nil)
      end

      it "returns true (optimistic default)" do
        expect(described_class.supports_hyperlinks?).to be true
      end
    end
  end
end
