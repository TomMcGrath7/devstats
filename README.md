# DevStats

DevStats is a collection of shell scripts that generate **developer stats** across multiple local Git repos.

- `devstats_daily.sh` — stats for a single day
- `devstats_range.sh` — aggregate stats over a date range (weekend, week, month, etc.)

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
chmod +x bin/devstats_daily.sh bin/devstats_range.sh
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

## Date range stats

Use `devstats_range.sh` to aggregate stats over multiple days — useful for reviewing a weekend, a full week, or a month.

### Preset ranges

```bash
RANGE=weekend ./bin/devstats_range.sh        # Last Sat-Sun
RANGE=last-week ./bin/devstats_range.sh      # Previous Mon-Sun
RANGE=this-week ./bin/devstats_range.sh      # This Mon to today
RANGE=last-7 ./bin/devstats_range.sh         # Last 7 days
RANGE=last-14 ./bin/devstats_range.sh        # Last 14 days
RANGE=last-30 ./bin/devstats_range.sh        # Last 30 days
RANGE=mtd ./bin/devstats_range.sh            # Month to date
RANGE=ytd ./bin/devstats_range.sh            # Year to date
```

### Custom date range

```bash
FROM=2026-01-13 TO=2026-01-17 ./bin/devstats_range.sh
```

### Show daily breakdown

Add `SHOW_DAILY=1` to see commits per day within the range:

```bash
RANGE=last-week SHOW_DAILY=1 ./bin/devstats_range.sh
```

## Set up terminal commands (aliases)

To make DevStats easy to run, add aliases to your shell.

For zsh on macOS, add to `~/.zshrc`:

```bash
# Daily stats
alias devstats="BASE=~/Documents/GitHub ~/Documents/GitHub/devstats/bin/devstats_daily.sh"

# Range stats
alias devstats-range="BASE=~/Documents/GitHub ~/Documents/GitHub/devstats/bin/devstats_range.sh"
```

Then reload:
```bash
source ~/.zshrc
```

After this, you can run:
```bash
devstats                           # Today's stats
WHEN=yesterday devstats            # Yesterday's stats
RANGE=weekend devstats-range       # Weekend stats
RANGE=last-week devstats-range     # Weekly stats
```

## Output examples

### Daily output

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
```

### Range output

```text
=== Last Week ===
Period: 2026-01-12 to 2026-01-18 (7 days)

Repos worked on: 5
Commits: 42
Code: +3200 / -800 | net: 2400 | total changed: 4000
Files changed: 85
Churn ratio (deleted/added): 0.25

Averages:
  Per commit: 95.2 lines
  Per day: 6.0 commits, 571 lines

PRs: opened=3, merged=2

Repos (top):
 - repo-a: 20 commits, 2500 lines changed
 - repo-b: 15 commits, 1200 lines changed

Language breakdown (by lines changed):
 - TypeScript: 60%
 - Python: 25%
 - Markdown: 15%

Daily breakdown:
  2026-01-12: 5 commits
  2026-01-13: 8 commits
  2026-01-14: 6 commits
  2026-01-15: 7 commits
  2026-01-16: 6 commits
  2026-01-17: 5 commits
  2026-01-18: 5 commits
```

## Notes

- Stats are based on **committed code only**.
- “Lines changed” is not a measure of productivity; it’s a lightweight reflection metric.
- Large initial commits or scaffolding work can produce large numbers.
- Repo names are taken directly from local folder names.

## License

MIT
