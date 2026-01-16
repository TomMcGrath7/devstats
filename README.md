# DevStats

DevStats is a small shell script that generates **daily developer stats** across multiple local Git repos.

It computes code stats locally from `git`, and can optionally include PR stats from GitHub via the GitHub CLI (`gh`).

## What it tracks

From your local Git commits:

- Repos worked on (repos with ≥1 commit in the selected day)
- Commits
- Lines added / deleted / net / total changed
- Files changed
- Churn ratio (deleted / added)
- Language breakdown (by lines changed, based on file extensions)

Optional (requires `gh`):

- PRs opened
- PRs merged

## Requirements

- macOS
- `zsh`
- `git`

Optional:
- GitHub CLI (`gh`) for PR stats

## Install

```bash
git clone https://github.com/YOUR_USERNAME/devstats.git
cd devstats
chmod +x bin/devstats_daily.sh
