#!/bin/zsh
# devstats_daily.sh
# Daily local Git stats + optional GitHub PR stats across many repos
# macOS + zsh

set -euo pipefail

# ---- help ----
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
DevStats — Daily developer stats from local Git repos

Usage:
  devstats_daily.sh [--help]

Configuration (environment variables):

  BASE
    Folder containing your Git repos.
    Example:
      BASE=~/Documents/GitHub

  WHEN
    Which day to report on:
      today        (default)
      yesterday
      YYYY-MM-DD
    Examples:
      WHEN=yesterday
      WHEN=2026-01-15

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

Examples:

  BASE=~/Documents/GitHub ./bin/devstats_daily.sh
  BASE=~/Documents/GitHub WHEN=yesterday ./bin/devstats_daily.sh
  INCLUDE_PRS=0 BASE=~/Documents/GitHub ./bin/devstats_daily.sh

Notes:
- Stats are based on committed code only.
- Large initial commits may produce large numbers.
- PR stats require GitHub CLI (gh) and authentication.

EOF
  exit 0
fi

# ---- configuration ----
BASE="${BASE:-$HOME/Documents/GitHub}"
WHEN="${WHEN:-today}"                       # today | yesterday | YYYY-MM-DD
AUTHOR_EMAIL="${AUTHOR_EMAIL:-$(git config --global user.email)}"

INCLUDE_PRS="${INCLUDE_PRS:-1}"             # 1 or 0
GH_BIN="${GH_BIN:-gh}"

# ---- determine time window ----
DAY=""
SINCE=""
UNTIL=""

if [[ "$WHEN" == "today" ]]; then
  DAY="$(date +%Y-%m-%d)"
  SINCE="midnight"
  UNTIL="now"
elif [[ "$WHEN" == "yesterday" ]]; then
  DAY="$(date -v-1d +%Y-%m-%d)"
  SINCE="yesterday midnight"
  UNTIL="midnight"
elif [[ "$WHEN" =~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' ]]; then
  DAY="$WHEN"
  SINCE="$WHEN 00:00"
  UNTIL="$WHEN 23:59:59"
else
  echo "Invalid WHEN=$WHEN. Use: today | yesterday | YYYY-MM-DD"
  exit 2
fi

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
trap 'rm -f "$tmp" "${tmp}.langs" 2>/dev/null || true' EXIT

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
done

if [[ ! -s "$tmp" ]]; then
  echo "No commits found for $DAY (author: $AUTHOR_EMAIL) under $BASE"
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

churn_ratio="0.00"
if [[ "$added_cnt" -gt 0 ]]; then
  churn_ratio="$(awk -v d="$deleted_cnt" -v a="$added_cnt" 'BEGIN{printf "%.2f", d/a}')"
fi

avg_change_per_commit="0.0"
if [[ "$commits_cnt" -gt 0 ]]; then
  avg_change_per_commit="$(awk -v t="$total_changed" -v c="$commits_cnt" 'BEGIN{printf "%.1f", t/c}')"
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
  prs_opened="$("$GH_BIN" search prs --author "@me" --created "$DAY" --json number --limit 300 2>/dev/null | wc -l | tr -d ' ')"
  prs_merged="$("$GH_BIN" search prs --author "@me" --merged "$DAY" --json number --limit 300 2>/dev/null | wc -l | tr -d ' ')"
fi

# ---- output ----
echo ""
echo "Date: $DAY"
echo "Repos worked on: $repos_cnt"
echo "Commits: $commits_cnt"
echo "Code: +$added_cnt / -$deleted_cnt | net: $net_changed | total changed: $total_changed"
echo "Files changed: $files_cnt"
echo "Churn ratio (deleted/added): $churn_ratio"
echo "Avg lines changed/commit: $avg_change_per_commit"
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
