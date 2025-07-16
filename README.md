# self-review

A CLI tool for retrieving and summarizing your work items from Github and Jira over a given time window.

I made this to streamline the process of recalling what I've worked on recently for the purposes of Artsy’s development cycle self-review.

Examples:

```sh
./bin/self-review "1 month"
./bin/self-review "q2"
./bin/self-review "first half this year"
```

The output would start something like this…

<img width="1486" height="1498" alt="review" src="https://github.com/user-attachments/assets/b520dc51-d0d4-4e7e-b435-128b84d3ea07" />

…and continue with your actual work items & clusters.


## What it does

- Determines a time window based on your natural language descriptor ("q2 this year", etc)
- Fetches recent Github PRs authored by you and merged during the time window
- Fetches recent Jira tickets assigned to you and completed during the time window
- Uses an LLM to cluster and summarize these into _hopefully_ coherent groups (YMMV)

## Does it work?

The deterministic bit of fetching and listing the relevant PRs and tickets definitely works and could be your own jumping off point if you don't want the LLM summary.

The LLM summaries are hit-or-miss, often differing between runs even over the same time window. Perhaps this could be improved.

## Do I need to use the LLM magic?

Magic is currently applied to natural language time window descriptions, and clustering and summarization of work activity.

You can bypass both with 

```sh
./bin/self-review fetch --since=2025-07-01
```

This will only fetch GH and Jira items based on the supplied date in ISO format, and won't bother with any LLM calls.

The results will be dumped to a local yaml file, but the program is not currently optimized for working with that nicely. It could be, though.

## Getting started

```sh
./bin/self-review setup # guides you through obtaining and configuring API tokens

./bin/self-review check # confirms your API connections are working

./bin/self-review help # show detailed usage info

./bin/self-review "1 week" # or just start summarizing
```

## Claude stuff

See [the first commit](https://github.com/anandaroop/self-review/commit/386d7205c8704f546c8ef7cdab74d9d3f474cb31), which sets up the CLAUDE.md file that largely guided the development of this tool. Mostly Claude working TDD style, with me steering & nudging as needed.
