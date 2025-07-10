# self-review

This project is a Ruby CLI that will:

- Fetch my recent work
  - Github PRs that were authored by me and merged
  - Jira tickets that were assigned to me and marked Done

Based on those descriptions the tool can also:

- group the work into a few clusters
- describe each cluster
- summarize my accomplishments in a few bullet points

## Stack

- Language: Ruby
- Framework: Dry
- Code quality: StandardRB
- Tests: RSpec
- Dependencies: Rainbow, Octokit, RubyLLM
- APIs: Github, Jira, Anthropic Claude, OpenAI GPT

## Additional documentation

- RubyLLM is a newer library so you may need to read the following docs:
  - Installation: https://rubyllm.com/installation
  - Configuration: https://rubyllm.com/configuration
  - Chatting with models: https://rubyllm.com/guides/chat
  - (and other guides are at https://rubyllm.com/guides/)

## Conventions

- Avoid fancy metaprogramming
- Share plans before writing code
- Write test-first (TDD)
- Lint before committing
- Use Conventional Commits message format
- Modify and update the **Planning Checklist** section below as we go
- Make judicious use of colored terminal output in the CLI implementation

## User stories

### User views help message

```
As a user
When I run `self-review` or `self-review help` or `self-review --help`
Then I am instructed how to use the program
```

### User configures the program

```
As a user
When I run `self-review setup`
Then I am instructed how to obtain and save credentials
So that the program can access any required APIs
```

### User checks configuration

```
As a user
Given that I have saved credentials for the required APIs
When I run `self-review check`
Then the program checks that it can access the required APIs
And reports status back to the user for each API.
```

### User fetches recent work

```
As a user
Given that I have saved credentials for the required APIs
When I run the command `self-review fetch`
Then the program fetches the Github and Jira data within the default (1 month) or requested (`--since`) time window
And caches it to a local file `recent-work-YYMMDD-HHMMSS.yml`
```

### User fetches recent work within a natural language date range

```
As a user
Given that I have saved credentials for the required APIs
When I run a command with a natural language date range e.g. `self-review fetch "last 3 months"` or `self-review fetch "first half of 2025"` or `self-review fetch "q2 of this year"`
Then the program parses that natural language into a structured date range
And fetches the Github and Jira data within that time window
And caches it to a local file `recent-work-YYMMDD-HHMMSS.yml`
```

### User analyzes recent work

```
As a user
Given that I fetched and cached recent work
When I run the command `self-review analyze`
Then the program reads the cached recent work data
And prompts an LLM to identify clusters
And prompts an LLM to turn the clusters into a bullet list of accomplishments
And saves the clusters and accomplishments to a local file `analysis-YYMMDD-HHMMSS.md`
```

## Planning Checklist

- [x] Setup the skeleton of the CLI
  - [x] Create Ruby project structure (Gemfile, bin/, lib/, spec/)
  - [x] Setup Dry framework foundation
  - [x] Create executable script in bin/self-review
  - [x] Configure StandardRB and RSpec
- [x] Implement help command functionality
  - [x] Create command router/dispatcher
  - [x] Implement help text display
  - [x] Add colored terminal output
- [x] Implement setup command for credential management
  - [x] Create credential storage system
  - [x] Add GitHub token configuration
  - [x] Add Jira API configuration
  - [x] Add LLM API configuration (Anthropic Claude & OpenAI GPT)
  - [x] Provide user-friendly setup instructions
- [x] Implement check command for API connectivity
  - [x] Create GitHub API connectivity test
  - [x] Create Jira API connectivity test
  - [x] Add LLM API connectivity test
  - [x] Add colored status reporting
  - [x] Handle and report API errors gracefully
- [x] Implement fetch command for data retrieval
  - [x] Create GitHub API client using Octokit
  - [x] Implement PR fetching with date filtering
  - [x] Create Jira API client
  - [x] Implement ticket fetching with date filtering
  - [x] Add caching to timestamped YAML files
- [x] Implement analyze command for LLM processing
  - [x] Create LLM integration using RubyLLM
  - [x] Implement work clustering algorithm using Claude/GPT
  - [x] Generate accomplishment summaries
  - [x] Save analysis to timestamped markdown files
  - [x] Add --verbose flag for optional LLM debugging output
  - [x] Add terminal markdown rendering for analysis output
- [x] Implement natural language date parsing for fetch command
  - [x] Create DateParser service with LLM integration
  - [x] Add support for natural language date ranges
  - [x] Maintain backward compatibility with --since=YYYY-MM-DD
  - [x] Include current date context in LLM prompts
  - [x] Handle edge cases and validation
- [x] Implement one-liner fetch+analyze command
  - [x] Create AutoAnalyze command combining fetch and analyze
  - [x] Add custom routing in bin/self-review for natural language inputs
  - [x] Maintain backward compatibility with all existing commands
  - [x] Update help text to showcase one-liner functionality
- [ ] Add comprehensive test coverage
  - [ ] Unit tests for all commands
  - [ ] Integration tests for API clients
  - [ ] Test credential management
  - [ ] Test file I/O operations
