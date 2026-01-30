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

  TOP_REPOS
    Number of top repos to display:
      5  (default)
      0  show all repos

  TOP_LANGS
    Number of top languages to display:
      6  (default)
      0  show all languages

  EXCLUDE_LANGS
    Comma-separated list of languages to exclude from breakdown.
    Uses the display names (case-insensitive).
    Examples:
      EXCLUDE_LANGS="JSON"
      EXCLUDE_LANGS="JSON,Markdown,YAML"

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
TOP_REPOS="${TOP_REPOS:-5}"
TOP_LANGS="${TOP_LANGS:-6}"
EXCLUDE_LANGS="${EXCLUDE_LANGS:-}"

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
    mjs|cjs) echo "JavaScript" ;;
    py) echo "Python" ;;
    pyx|pxd|pxi) echo "Cython" ;;
    go) echo "Go" ;;
    rb) echo "Ruby" ;;
    java) echo "Java" ;;
    kt|kts) echo "Kotlin" ;;
    swift) echo "Swift" ;;
    rs) echo "Rust" ;;
    c) echo "C" ;;
    h|hpp|hh|hxx|cpp|cc|cxx) echo "C/C++" ;;
    cs) echo "C#" ;;
    fs|fsx|fsi) echo "F#" ;;
    php) echo "PHP" ;;
    html|htm) echo "HTML" ;;
    css) echo "CSS" ;;
    scss|sass|less) echo "CSS/SCSS" ;;
    md|mdx) echo "Markdown" ;;
    yml|yaml) echo "YAML" ;;
    json|jsonc|json5) echo "JSON" ;;
    sql) echo "SQL" ;;
    sh|zsh|bash|fish) echo "Shell" ;;
    toml) echo "TOML" ;;
    xml|xsl|xslt) echo "XML" ;;
    vue) echo "Vue" ;;
    svelte) echo "Svelte" ;;
    astro) echo "Astro" ;;
    lua) echo "Lua" ;;
    r|R) echo "R" ;;
    jl) echo "Julia" ;;
    ex|exs) echo "Elixir" ;;
    erl|hrl) echo "Erlang" ;;
    hs|lhs) echo "Haskell" ;;
    ml|mli) echo "OCaml" ;;
    clj|cljs|cljc|edn) echo "Clojure" ;;
    scala|sc) echo "Scala" ;;
    groovy|gvy|gy|gsh) echo "Groovy" ;;
    dart) echo "Dart" ;;
    zig) echo "Zig" ;;
    nim) echo "Nim" ;;
    v) echo "V" ;;
    cr) echo "Crystal" ;;
    pl|pm) echo "Perl" ;;
    tf|tfvars) echo "Terraform" ;;
    proto) echo "Protobuf" ;;
    graphql|gql) echo "GraphQL" ;;
    prisma) echo "Prisma" ;;
    sol) echo "Solidity" ;;
    move) echo "Move" ;;
    cairo) echo "Cairo" ;;
    ipynb) echo "Jupyter" ;;
    tex|latex) echo "LaTeX" ;;
    rst) echo "reStructuredText" ;;
    org) echo "Org" ;;
    txt) echo "Text" ;;
    csv) echo "CSV" ;;
    lock) echo "Lockfile" ;;
    dockerfile|Dockerfile) echo "Dockerfile" ;;
    makefile|Makefile|mk) echo "Makefile" ;;
    cmake) echo "CMake" ;;
    gradle) echo "Gradle" ;;
    properties) echo "Properties" ;;
    ini|cfg|conf) echo "Config" ;;
    env) echo "Env" ;;
    gitignore|gitattributes) echo "Git" ;;
    editorconfig) echo "EditorConfig" ;;
    pbxproj|xcscheme|xcworkspacedata|xcuserstate|xcbkptlist) echo "Xcode" ;;
    plist|entitlements) echo "Plist" ;;
    svg) echo "SVG" ;;
    png|jpg|jpeg|gif|webp|ico|icns) echo "Image" ;;
    woff|woff2|ttf|otf|eot) echo "Font" ;;
    mp3|wav|ogg|flac|m4a) echo "Audio" ;;
    mp4|mov|avi|mkv|webm) echo "Video" ;;
    pdf) echo "PDF" ;;
    zip|tar|gz|rar|7z) echo "Archive" ;;
    dockerignore) echo "Docker" ;;
    eslintrc|prettierrc|babelrc) echo "Config" ;;
    nvmrc|npmrc|yarnrc) echo "Config" ;;
    graphqls) echo "GraphQL" ;;
    prisma) echo "Prisma" ;;
    snap) echo "Snapshot" ;;
    storyboard|xib) echo "Xcode" ;;
    strings|stringsdict) echo "Strings" ;;
    modulemap) echo "Modulemap" ;;
    xcconfig) echo "Xcode" ;;
    podspec) echo "CocoaPods" ;;
    gemspec) echo "Ruby" ;;
    rake|gemfile) echo "Ruby" ;;
    NoExt) echo "NoExt" ;;
    *) echo "${ext:u}" ;;
  esac
}

# ---- check if language should be excluded ----
is_excluded_lang() {
  local lang="$1"
  [[ -z "$EXCLUDE_LANGS" ]] && return 1
  local exclude_lower
  exclude_lower="$(echo "$EXCLUDE_LANGS" | tr '[:upper:]' '[:lower:]')"
  local lang_lower
  lang_lower="$(echo "$lang" | tr '[:upper:]' '[:lower:]')"
  echo "$exclude_lower" | tr ',' '\n' | while read -r excluded; do
    excluded="$(echo "$excluded" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ "$lang_lower" == "$excluded" ]] && return 0
  done
  return 1
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

if [[ "$TOP_REPOS" -eq 0 ]]; then
  echo "Repos (all):"
else
  echo "Repos (top $TOP_REPOS):"
fi
i=0
echo "$repos_list" | while IFS=$'\t' read -r repo totchg c; do
  i=$((i+1))
  [[ "$TOP_REPOS" -gt 0 && "$i" -gt "$TOP_REPOS" ]] && break
  echo " - ${repo:t}: $c commits, $totchg lines changed"
done

if [[ -n "$lang_summary" ]]; then
  echo ""
  # Aggregate by language label (not extension) and filter exclusions
  typeset -A lang_totals
  filtered_total=0
  while IFS=$'\t' read -r ext ch tot; do
    label="$(lang_label "$ext")"
    if ! is_excluded_lang "$label"; then
      lang_totals[$label]=$((${lang_totals[$label]:-0} + ch))
      filtered_total=$((filtered_total + ch))
    fi
  done <<< "$lang_summary"

  # Sort by count descending
  sorted_langs=""
  for label in "${(@k)lang_totals}"; do
    sorted_langs="${sorted_langs}${label}\t${lang_totals[$label]}\n"
  done
  sorted_langs="$(printf "$sorted_langs" | sort -t$'\t' -k2,2nr)"

  if [[ "$TOP_LANGS" -eq 0 ]]; then
    echo "Language breakdown (by lines changed):"
  elif [[ -n "$EXCLUDE_LANGS" ]]; then
    echo "Language breakdown (top $TOP_LANGS, excluding: $EXCLUDE_LANGS):"
  else
    echo "Language breakdown (top $TOP_LANGS):"
  fi
  i=0
  printf "$sorted_langs" | while IFS=$'\t' read -r label ch; do
    [[ -z "$label" ]] && continue
    i=$((i+1))
    [[ "$TOP_LANGS" -gt 0 && "$i" -gt "$TOP_LANGS" ]] && break
    pct="$(awk -v c="$ch" -v t="$filtered_total" 'BEGIN{ if (t>0) printf "%.0f", (100*c/t); else print "0"}')"
    echo " - $label: $pct%"
  done
fi
