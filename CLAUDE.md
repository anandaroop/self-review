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
- Dependencies: Rainbow, Octokit
- APIs: Github, Jira

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

### User fetches recent work

```
As a user
Given that I have saved credentials for the required APIs
When I run the command `self-review fetch`
Then the program fetches the Github and Jira data within the default (1 month) or requested (`--since`) time window
And caches it to a local file `recent-work-YYMMDD-HHMMSS.md`
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

- [ ] Setup the skeleton of the CLI
