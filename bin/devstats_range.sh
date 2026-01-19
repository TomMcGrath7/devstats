#!/bin/zsh
# devstats_range.sh
# Aggregate Git stats over a date range across many repos
# macOS + zsh

set -euo pipefail

# ---- help ----
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
DevStats Range — Developer stats aggregated over a date range

Usage:
  devstats_range.sh [--help]

Configuration (environment variables):

  BASE
    Folder containing your Git repos.
    Example:
      BASE=~/Documents/GitHub

  FROM / TO
    Date range to report on (YYYY-MM-DD format).
    Examples:
      FROM=2026-01-13 TO=2026-01-17
      FROM=2026-01-01 TO=2026-01-31

  RANGE
    Preset date ranges (alternative to FROM/TO):
      last-week     Previous Mon-Sun
      this-week     Current week Mon-today
      weekend       Last Sat-Sun
      last-weekend  Previous Sat-Sun
      last-7        Last 7 days
      last-14       Last 14 days
      last-30       Last 30 days
      mtd           Month to date
      ytd           Year to date
    Examples:
      RANGE=weekend
      RANGE=last-week

  INCLUDE_PRS
    Include PR stats via GitHub CLI (gh):
      1  (default)
      0  disable PR stats

  AUTHOR_EMAIL
    Commit author filter.
    Defaults to: git config --global user.email
    Supports regex for multiple emails.
    Example:
      AUTHOR_EMAIL="(me@work.com|me@gmail.com)"

  SHOW_DAILY
    Show per-day breakdown:
      0  (default) summary only
      1  include daily stats

Examples:

  RANGE=weekend BASE=~/Documents/GitHub ./bin/devstats_range.sh
  RANGE=last-week ./bin/devstats_range.sh
  FROM=2026-01-13 TO=2026-01-17 ./bin/devstats_range.sh
  RANGE=last-week SHOW_DAILY=1 ./bin/devstats_range.sh

Notes:
- Stats are based on committed code only.
- Large initial commits may produce large numbers.
- PR stats require GitHub CLI (gh) and authentication.

EOF
  exit 0
fi

# ---- configuration ----
BASE="${BASE:-$HOME/Documents/GitHub}"
AUTHOR_EMAIL="${AUTHOR_EMAIL:-$(git config --global user.email)}"
INCLUDE_PRS="${INCLUDE_PRS:-1}"
GH_BIN="${GH_BIN:-gh}"
SHOW_DAILY="${SHOW_DAILY:-0}"

# ---- determine date range ----
FROM_DATE=""
TO_DATE=""
RANGE_LABEL=""

calculate_range() {
  local range="$1"
  local today
  today="$(date +%Y-%m-%d)"

  # Get day of week (1=Monday, 7=Sunday)
  local dow
  dow="$(date +%u)"

  case "$range" in
    last-week)
      # Previous Monday to Sunday
      local days_since_monday=$((dow - 1))
      local last_sunday=$((days_since_monday + 1))
      local last_monday=$((days_since_monday + 7))
      FROM_DATE="$(date -v-${last_monday}d +%Y-%m-%d)"
      TO_DATE="$(date -v-${last_sunday}d +%Y-%m-%d)"
      RANGE_LABEL="Last Week"
      ;;
    this-week)
      # This Monday to today
      local days_since_monday=$((dow - 1))
      FROM_DATE="$(date -v-${days_since_monday}d +%Y-%m-%d)"
      TO_DATE="$today"
      RANGE_LABEL="This Week"
      ;;
    weekend)
      # Most recent Sat-Sun (could be ongoing or just passed)
      if [[ "$dow" -eq 6 ]]; then
        # Today is Saturday
        FROM_DATE="$today"
        TO_DATE="$(date -v+1d +%Y-%m-%d)"
        RANGE_LABEL="This Weekend"
      elif [[ "$dow" -eq 7 ]]; then
        # Today is Sunday
        FROM_DATE="$(date -v-1d +%Y-%m-%d)"
        TO_DATE="$today"
        RANGE_LABEL="This Weekend"
      else
        # Weekday - show last weekend
        local days_since_sunday=$dow
        local days_since_saturday=$((dow + 1))
        FROM_DATE="$(date -v-${days_since_saturday}d +%Y-%m-%d)"
        TO_DATE="$(date -v-${days_since_sunday}d +%Y-%m-%d)"
        RANGE_LABEL="Last Weekend"
      fi
      ;;
    last-weekend)
      # Previous Sat-Sun (always in the past)
      local days_since_sunday
      if [[ "$dow" -eq 7 ]]; then
        days_since_sunday=7
      else
        days_since_sunday=$((dow + 7))
      fi
      local days_since_saturday=$((days_since_sunday + 1))
      FROM_DATE="$(date -v-${days_since_saturday}d +%Y-%m-%d)"
      TO_DATE="$(date -v-${days_since_sunday}d +%Y-%m-%d)"
      RANGE_LABEL="Last Weekend"
      ;;
    last-7)
      FROM_DATE="$(date -v-6d +%Y-%m-%d)"
      TO_DATE="$today"
      RANGE_LABEL="Last 7 Days"
      ;;
    last-14)
      FROM_DATE="$(date -v-13d +%Y-%m-%d)"
      TO_DATE="$today"
      RANGE_LABEL="Last 14 Days"
      ;;
    last-30)
      FROM_DATE="$(date -v-29d +%Y-%m-%d)"
      TO_DATE="$today"
      RANGE_LABEL="Last 30 Days"
      ;;
    mtd)
      # Month to date
      FROM_DATE="$(date +%Y-%m-01)"
      TO_DATE="$today"
      RANGE_LABEL="Month to Date"
      ;;
    ytd)
      # Year to date
      FROM_DATE="$(date +%Y-01-01)"
      TO_DATE="$today"
      RANGE_LABEL="Year to Date"
      ;;
    *)
      echo "Unknown RANGE=$range"
      echo "Valid options: last-week, this-week, weekend, last-weekend, last-7, last-14, last-30, mtd, ytd"
      exit 2
      ;;
  esac
}

# Handle RANGE preset or FROM/TO explicit dates
if [[ -n "${RANGE:-}" ]]; then
  calculate_range "$RANGE"
elif [[ -n "${FROM:-}" && -n "${TO:-}" ]]; then
  if [[ ! "$FROM" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
    echo "Invalid FROM=$FROM. Use YYYY-MM-DD format."
    exit 2
  fi
  if [[ ! "$TO" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
    echo "Invalid TO=$TO. Use YYYY-MM-DD format."
    exit 2
  fi
  FROM_DATE="$FROM"
  TO_DATE="$TO"
  RANGE_LABEL="$FROM_DATE to $TO_DATE"
else
  echo "Specify either RANGE or both FROM and TO."
  echo "Examples:"
  echo "  RANGE=last-week ./bin/devstats_range.sh"
  echo "  FROM=2026-01-13 TO=2026-01-17 ./bin/devstats_range.sh"
  echo ""
  echo "Run with --help for full usage."
  exit 2
fi

SINCE="$FROM_DATE 00:00"
UNTIL="$TO_DATE 23:59:59"

# ---- language labels ----
lang_label() {
  local ext="$1"
  case "$ext" in
    js) echo "JavaScript" ;;
    ts) echo "TypeScript" ;;
    jsx) echo "JSX" ;;
    tsx) echo "TSX" ;;
    py) echo "Python" ;;
    go) echo "Go" ;;
    rb) echo "Ruby" ;;
    java) echo "Java" ;;
    kt) echo "Kotlin" ;;
    swift) echo "Swift" ;;
    rs) echo "Rust" ;;
    c) echo "C" ;;
    h|hpp|hh|hxx|cpp|cc|cxx) echo "C/C++" ;;
    cs) echo "C#" ;;
    php) echo "PHP" ;;
    html) echo "HTML" ;;
    css) echo "CSS" ;;
    scss) echo "SCSS" ;;
    md) echo "Markdown" ;;
    yml|yaml) echo "YAML" ;;
    json) echo "JSON" ;;
    sql) echo "SQL" ;;
    sh|zsh|bash) echo "Shell" ;;
    toml) echo "TOML" ;;
    NoExt) echo "NoExt" ;;
    *) echo "${ext:u}" ;;
  esac
}

# ---- gather per-repo stats ----
tmp="$(mktemp)"
trap 'rm -f "$tmp" "${tmp}.langs" "${tmp}.daily" 2>/dev/null || true' EXIT

find "$BASE" -type d -name ".git" -prune 2>/dev/null | while read -r gitdir; do
  repo="$(dirname "$gitdir")"
  cd "$repo" 2>/dev/null || continue

  commits="$(git log --since="$SINCE" --until="$UNTIL" --author="$AUTHOR_EMAIL" --pretty=oneline 2>/dev/null \
    | wc -l | tr -d ' ')"
  [[ "${commits:-0}" -eq 0 ]] && continue

  numstat="$(git log --since="$SINCE" --until="$UNTIL" --author="$AUTHOR_EMAIL" --pretty=tformat: --numstat 2>/dev/null || true)"

  added_deleted="$(printf "%s\n" "$numstat" | awk '
    NF==3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {a+=$1; d+=$2}
    END {printf "%d %d", a+0, d+0}
  ')"

  added="${added_deleted%% *}"
  deleted="${added_deleted##* }"

  files_changed="$(git log --since="$SINCE" --until="$UNTIL" --author="$AUTHOR_EMAIL" --name-only --pretty=tformat: 2>/dev/null \
    | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"

  lang_lines="$(printf "%s\n" "$numstat" | awk '
    NF==3 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
      file=$3
      n=split(file, parts, ".")
      ext=(n>1?parts[n]:"NoExt")
      ch=$1+$2
      m[ext]+=ch
      tot+=ch
    }
    END { for (e in m) printf "%s\t%d\t%d\n", e, m[e], tot }
  ')"

  printf "%s\t%s\t%s\t%s\t%s\n" "$repo" "$commits" "$added" "$deleted" "$files_changed" >> "$tmp"

  if [[ -n "$lang_lines" ]]; then
    printf "%s\n" "$lang_lines" | while IFS=$'\t' read -r ext ch tot; do
      printf "%s\t%s\t%s\n" "$repo" "$ext" "$ch" >> "${tmp}.langs"
    done
  fi

  # Gather daily stats if requested
  if [[ "$SHOW_DAILY" == "1" ]]; then
    git log --since="$SINCE" --until="$UNTIL" --author="$AUTHOR_EMAIL" --pretty=format:"%ad" --date=short 2>/dev/null \
      | sort | uniq -c | while read -r count day; do
        printf "%s\t%s\t%s\n" "$day" "$repo" "$count" >> "${tmp}.daily"
      done
  fi
done

if [[ ! -s "$tmp" ]]; then
  echo "No commits found for $RANGE_LABEL (author: $AUTHOR_EMAIL) under $BASE"
  exit 0
fi

# ---- totals ----
totals="$(awk -F'\t' '
  {repos+=1; commits+=$2; added+=$3; deleted+=$4; files+=$5}
  END {printf "%d %d %d %d %d", repos, commits, added, deleted, files}
' "$tmp")"

repos_cnt="$(echo "$totals" | awk '{print $1}')"
commits_cnt="$(echo "$totals" | awk '{print $2}')"
added_cnt="$(echo "$totals" | awk '{print $3}')"
deleted_cnt="$(echo "$totals" | awk '{print $4}')"
files_cnt="$(echo "$totals" | awk '{print $5}')"

total_changed=$((added_cnt + deleted_cnt))
net_changed=$((added_cnt - deleted_cnt))

# Calculate number of days in range
days_in_range=$(( ( $(date -j -f "%Y-%m-%d" "$TO_DATE" +%s) - $(date -j -f "%Y-%m-%d" "$FROM_DATE" +%s) ) / 86400 + 1 ))

churn_ratio="0.00"
if [[ "$added_cnt" -gt 0 ]]; then
  churn_ratio="$(awk -v d="$deleted_cnt" -v a="$added_cnt" 'BEGIN{printf "%.2f", d/a}')"
fi

avg_change_per_commit="0.0"
if [[ "$commits_cnt" -gt 0 ]]; then
  avg_change_per_commit="$(awk -v t="$total_changed" -v c="$commits_cnt" 'BEGIN{printf "%.1f", t/c}')"
fi

avg_commits_per_day="0.0"
if [[ "$days_in_range" -gt 0 ]]; then
  avg_commits_per_day="$(awk -v c="$commits_cnt" -v d="$days_in_range" 'BEGIN{printf "%.1f", c/d}')"
fi

avg_lines_per_day="0.0"
if [[ "$days_in_range" -gt 0 ]]; then
  avg_lines_per_day="$(awk -v t="$total_changed" -v d="$days_in_range" 'BEGIN{printf "%.0f", t/d}')"
fi

# ---- top repos ----
repos_list="$(awk -F'\t' '{print $1 "\t" ($3+$4) "\t" $2}' "$tmp" | sort -k2,2nr)"

# ---- language aggregation ----
lang_summary=""
if [[ -f "${tmp}.langs" ]]; then
  lang_summary="$(awk -F'\t' '
    {m[$2]+=$3; tot+=$3}
    END {for (e in m) printf "%s\t%d\t%d\n", e, m[e], tot}
  ' "${tmp}.langs" | sort -k2,2nr)"
fi

# ---- PR stats (optional) ----
prs_opened="(skipped)"
prs_merged="(skipped)"
if [[ "$INCLUDE_PRS" == "1" ]] && command -v "$GH_BIN" >/dev/null 2>&1; then
  prs_opened="$("$GH_BIN" search prs --author "@me" --created "$FROM_DATE..$TO_DATE" --json number --limit 300 2>/dev/null | wc -l | tr -d ' ')"
  prs_merged="$("$GH_BIN" search prs --author "@me" --merged "$FROM_DATE..$TO_DATE" --json number --limit 300 2>/dev/null | wc -l | tr -d ' ')"
fi

# ---- output ----
echo ""
echo "=== $RANGE_LABEL ==="
echo "Period: $FROM_DATE to $TO_DATE ($days_in_range days)"
echo ""
echo "Repos worked on: $repos_cnt"
echo "Commits: $commits_cnt"
echo "Code: +$added_cnt / -$deleted_cnt | net: $net_changed | total changed: $total_changed"
echo "Files changed: $files_cnt"
echo "Churn ratio (deleted/added): $churn_ratio"
echo ""
echo "Averages:"
echo "  Per commit: $avg_change_per_commit lines"
echo "  Per day: $avg_commits_per_day commits, $avg_lines_per_day lines"
echo ""
echo "PRs: opened=$prs_opened, merged=$prs_merged"
echo ""

echo "Repos (top):"
i=0
echo "$repos_list" | while IFS=$'\t' read -r repo totchg c; do
  i=$((i+1))
  [[ "$i" -gt 5 ]] && break
  echo " - ${repo:t}: $c commits, $totchg lines changed"
done

if [[ -n "$lang_summary" ]]; then
  echo ""
  echo "Language breakdown (by lines changed):"
  i=0
  echo "$lang_summary" | while IFS=$'\t' read -r ext ch tot; do
    i=$((i+1))
    [[ "$i" -gt 6 ]] && break
    pct="$(awk -v c="$ch" -v t="$tot" 'BEGIN{ if (t>0) printf "%.0f", (100*c/t); else print "0"}')"
    echo " - $(lang_label "$ext"): $pct%"
  done
fi

# ---- daily breakdown (optional) ----
if [[ "$SHOW_DAILY" == "1" && -f "${tmp}.daily" && -s "${tmp}.daily" ]]; then
  echo ""
  echo "Daily breakdown:"
  awk -F'\t' '{commits[$1]+=$3} END {for (day in commits) printf "%s\t%d\n", day, commits[day]}' "${tmp}.daily" \
    | sort -k1,1 \
    | while IFS=$'\t' read -r day count; do
        echo "  $day: $count commits"
      done
fi
