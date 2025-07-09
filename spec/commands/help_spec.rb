require "spec_helper"

RSpec.describe SelfReview::Commands::Help do
  it "displays help text with usage information" do
    expect { subject.call }.to output(/Usage: self-review/).to_stdout
  end

  it "displays available commands" do
    expect { subject.call }.to output(/Commands:/).to_stdout
  end

  it "displays examples" do
    expect { subject.call }.to output(/Examples:/).to_stdout
  end
end
