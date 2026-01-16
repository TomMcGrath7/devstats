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

Optional (requires GitHub CLI):

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
```

## Quick start

Run DevStats against a folder that contains your Git repos
(GitHub Desktop’s default is often `~/Documents/GitHub`):

```bash
BASE=~/Documents/GitHub ./bin/devstats_daily.sh
```

## Pick a day (today / yesterday / specific date)

DevStats reports on a single day using the `WHEN` environment variable.

Supported values:

- `today` (default)
- `yesterday`
- a specific date in `YYYY-MM-DD` format

Examples:

```bash
BASE=~/Documents/GitHub ./bin/devstats_daily.sh
BASE=~/Documents/GitHub WHEN=yesterday ./bin/devstats_daily.sh
BASE=~/Documents/GitHub WHEN=2026-01-15 ./bin/devstats_daily.sh
```

## Optional: include / exclude PR stats

PR stats (opened / merged) are fetched via the GitHub CLI (`gh`).

If you don’t want PR stats, or you don’t have `gh` installed:

```bash
INCLUDE_PRS=0 BASE=~/Documents/GitHub ./bin/devstats_daily.sh
```

To enable PR stats:

```bash
brew install gh
gh auth login
```

## Optional: filter by author email

By default, DevStats uses your global git email:

```bash
git config --global user.email
```

If you commit using multiple emails (for example, work + personal), you can
override the author filter using a regular expression:

```bash
AUTHOR_EMAIL="(me@work.com|me@gmail.com)" BASE=~/Documents/GitHub ./bin/devstats_daily.sh
```

## Set up a terminal command (alias)

To make DevStats easy to run daily, you can add an alias to your shell.

For zsh on macOS:

```bash
echo 'alias devstats="BASE=~/Documents/GitHub ~/devstats/bin/devstats_daily.sh"' >> ~/.zshrc
source ~/.zshrc
```

After this, you can run:
```bash
devstats
WHEN=yesterday devstats
```

## Output example

```text
Date: 2026-01-16
Repos worked on: 1
Commits: 3
Code: +120 / -40 | net: 80 | total changed: 160
Files changed: 12
Churn ratio (deleted/added): 0.33
Avg lines changed/commit: 53.3
PRs: opened=1, merged=0

Repos (top):
 - repo-a: 2 commits, 120 lines changed
 - repo-b: 1 commits, 40 lines changed

Language breakdown (by lines changed):
 - TypeScript: 70%
 - Markdown: 20%
 - YAML: 10%

## Notes

- Stats are based on **committed code only**.
- “Lines changed” is not a measure of productivity; it’s a lightweight reflection metric.
- Large initial commits or scaffolding work can produce large numbers.
- Repo names are taken directly from local folder names.

## License

MIT
