#!/usr/bin/env bash
# Checks spec/forever-plan.md against the GitHub issues and reports tracking drift:
# - every plan row's [#N] exists, the issue title starts with the row's ID, and its
#   milestone matches the plan section; rows in a "Done:" line are closed issues or merged PRs
# - every open issue titled with a plan ID appears in the plan
# - every ticked box (issue bodies and plan gates) cites evidence: a merged PR (#N), a
#   backticked commit on main, "migration-forever.md YYYY-MM-DD", "decisions log YYYY-MM-DD",
#   a workflow run ID or URL, or a comment link
# - every closed issue was closed by a PR or commit, or carries an evidence comment; a
#   not-planned close carries a reason comment written at the close; a close by a PR (or its commit) whose Tracking block
#   doesn't list the issue under Finishes is flagged (#15)
# - merged PRs whose Tracking block hasn't been applied: no "Tracking applied" comment, or the
#   latest one lists Unmatched items
# - open umbrellas whose sub-issues are all closed
#
# Usage: bash tools/check-plan-index.sh [--summary] [--data DIR] [--plan FILE]
#   --summary  print one line for the session-start hook; never fails
#   --data     read issues.json, prs.json and main-shas.txt from DIR instead of GitHub (tests)
# Needs gh (authenticated) and jq. Exits 1 when it finds drift, 2 when it can't fetch.
set -u

repo=${GC_REPO:-lxhwes/GuildCrafts-Forever}
root=$(cd "$(dirname "$0")/.." && pwd)
plan=$root/spec/forever-plan.md
summary=0 data=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --summary) summary=1 ;;
        --data) data=$2; shift ;;
        --plan) plan=$2; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

cache=${XDG_CACHE_HOME:-$HOME/.cache}/guildcrafts/tracking-last
offline() {
    if [[ $summary -eq 1 ]]; then
        echo "Tracking: GitHub unreachable ($1); last check: $(cat "$cache" 2>/dev/null || echo never)"
        exit 0
    fi
    echo "check-plan-index: $1" >&2
    exit 2
}

if [[ -n $data ]]; then
    work=$data
else
    work=$(mktemp -d "${TMPDIR:-/tmp}/gc-plan-index.XXXXXX") || exit 2
    trap 'rm -rf "$work"' EXIT
    owner=${repo%/*} name=${repo#*/}
    # shellcheck disable=SC2016 # GraphQL variables, not shell
    q_issues='query($endCursor: String) { repository(owner: "'$owner'", name: "'$name'") {
      issues(first: 50, after: $endCursor) { pageInfo { hasNextPage endCursor } nodes {
        number title state stateReason body milestone { title } labels(first: 20) { nodes { name } }
        subIssuesSummary { total completed }
        comments(first: 100) { totalCount nodes { body createdAt } }
        timelineItems(last: 1, itemTypes: [CLOSED_EVENT]) { nodes { ... on ClosedEvent { createdAt closer {
          __typename ... on PullRequest { number body }
          ... on Commit { oid associatedPullRequests(first: 3) { nodes { number body } } } } } } } } } } }'
    # shellcheck disable=SC2016
    q_prs='query($endCursor: String) { repository(owner: "'$owner'", name: "'$name'") {
      pullRequests(states: MERGED, first: 50, after: $endCursor) { pageInfo { hasNextPage endCursor }
        nodes { number body mergeCommit { oid } comments(last: 30) { nodes { body } } } } } }'
    # gh prints a GraphQL error body to stdout, so check its exit status before parsing.
    gh api graphql --paginate -f query="$q_issues" --jq '.data.repository.issues.nodes[]' \
        >"$work/issues.raw" 2>"$work/err" || offline "$(head -c 120 "$work/err")"
    gh api graphql --paginate -f query="$q_prs" --jq '.data.repository.pullRequests.nodes[]' \
        >"$work/prs.raw" 2>"$work/err" || offline "$(head -c 120 "$work/err")"
    jq -s . "$work/issues.raw" >"$work/issues.json" && jq -s . "$work/prs.raw" >"$work/prs.json" &&
        [[ $(jq length "$work/issues.json") -gt 0 ]] || offline "no issues returned"
    git -C "$root" rev-list origin/main >"$work/main-shas.txt" 2>/dev/null || : >"$work/main-shas.txt"
fi

# Plan rows as TSV: kind, section, ID, number. kind is row, done, index or gate (a ticked box).
rows=$(awk '
    /^## / { sect = substr($0, 4); next }
    /^\[#[0-9]+\]: / { n = $1; gsub(/[^0-9]/, "", n); kind = ($2 ~ /\/pull\//) ? "pull" : "issue"
                       print "link\t-\t" kind "\t" n; next }
    /^- \[[xX]\]/ { line = $0; gsub(/\t/, " ", line); print "gate\t" sect "\t" line "\t0"; next }
    /^\|/ && /\[#[0-9]+\]/ && sect !~ /^Decisions log/ {
        split($0, cell, "|"); id = cell[2]; gsub(/~~|^ +| +$/, "", id)
        if (id !~ /^([A-Z]|—)/) next
        match($0, /\[#[0-9]+\]/); n = substr($0, RSTART + 2, RLENGTH - 3)
        print ((sect ~ /^Finding index/) ? "index" : "row") "\t" sect "\t" id "\t" n; next }
    /^(Done|Closed as not planned): / {
        line = $0; sub(/^[^:]*: /, "", line)
        while (match(line, /[A-Z][A-Za-z0-9.\/]* [^,;]*\[#[0-9]+\]/)) {
            m = substr(line, RSTART, RLENGTH); line = substr(line, RSTART + RLENGTH)
            id = m; sub(/ .*/, "", id); n = m; sub(/.*\[#/, "", n); sub(/\]/, "", n)
            print "done\t" sect "\t" id "\t" n }
    }' "$plan")

drift=$(jq -r -n --arg rows "$rows" --arg repo "$repo" \
    --slurpfile issues "$work/issues.json" --slurpfile prs "$work/prs.json" \
    --rawfile shas "$work/main-shas.txt" '
  ($issues[0] | map({key: (.number | tostring), value: .}) | from_entries) as $I
  | ($prs[0] | map({key: (.number | tostring), value: .}) | from_entries) as $P
  | ($shas | split("\n") | map(select(length > 0))) as $S
  | ($rows | split("\n") | map(select(length > 0) | split("\t")
      | {kind: .[0], sect: .[1], id: .[2], n: .[3]})) as $R
  | ($R | map(select(.kind == "link")) | map({key: .n, value: .id}) | from_entries) as $link
  | def evidence:
      ([scan("#([0-9]+)") | .[0] | select($P[.])] | length > 0)
      or ([scan("`([0-9a-f]{7,40})`") | .[0] as $h | select(any($S[]; startswith($h)))] | length > 0)
      or test("migration-forever\\.md [0-9]{4}-[0-9]{2}-[0-9]{2}")
      or test("decisions log [0-9]{4}-[0-9]{2}-[0-9]{2}")
      or test("(^|[^0-9])[0-9]{10,12}([^0-9]|$)") or test("/actions/runs/[0-9]+")
      or test("issuecomment-[0-9]+");
    # whole issues only: "#12" finishes #12, "#12 F8" or "#12 \"text\"" only ticks a line
    def finishes($pr):
      ($pr.body // "") | [scan("(?im)^Finishes:(.*)$") | .[0] | split(",")[]
        | gsub("^\\s+|\\s+$"; "") | select(test("^#[0-9]+$")) | .[1:] | tonumber];
    def has_tracking($pr): ($pr.body // "") | test("(?im)^### Tracking");
    def milestone_for($sect):
      if ($sect | test("^Phase [0-9]")) then ($sect | capture("^(?<p>Phase [0-9])").p)
      elif ($sect | test("^Post-launch")) then "Post-launch"
      elif ($sect | test("^Later")) then "Later" else null end;
    def idmatch($id; $title): ($id == "—") or ($title | startswith(($id | split(" ")[0]) + ":"));

    # plan rows
    ( $R[] | select(.kind == "row" or .kind == "done" or .kind == "index") | . as $r
      | if ($link[$r.n] // "issue") == "pull" then
          (if $P[$r.n] then empty else "plan: \($r.id) cites PR #\($r.n), which is not merged" end)
        elif ($I[$r.n] | not) then "plan: \($r.id) links #\($r.n), which does not exist"
        else $I[$r.n] as $i
          | ( if $r.kind != "index" and (idmatch($r.id; $i.title) | not)
                then "plan: \($r.id) links #\($r.n), titled \"\($i.title)\"" else empty end ),
            ( milestone_for($r.sect) as $m
              | if $r.kind != "index" and $m and ((($i.milestone.title // "") | startswith($m)) | not)
                  then "plan: \($r.id) [#\($r.n)] is under \"\($m)\" but its milestone is \"\($i.milestone.title // "none")\""
                  else empty end ),
            ( if $r.kind == "done" and $i.state != "CLOSED" then "plan: \($r.id) [#\($r.n)] is listed as done but is open" else empty end )
        end ),
    # open plan-ID issues missing from the plan
    ( ($R | map(select(.kind != "link" and .kind != "gate") | .n)) as $listed
      | $issues[0][] | select(.state == "OPEN" and (.title | test("^[A-Z]+[0-9][0-9A-Za-z./]*:")))
      | select((.number | tostring) as $n | ($listed | index($n)) | not)
      | "plan: #\(.number) \"\(.title)\" is open but not in the plan" ),
    # ticked boxes without evidence
    ( $issues[0][] | . as $i | (.body // "") | split("\n")[] | select(test("^\\s*- \\[[xX]\\]"))
      | select(evidence | not) | "#\($i.number): ticked without evidence: \(.[0:110])" ),
    ( $R[] | select(.kind == "gate") | select(.id | evidence | not)
      | "plan gate (\(.sect | split(" (")[0])): ticked without evidence: \(.id[0:110])" ),
    # closed issues
    ( $issues[0][] | select(.state == "CLOSED") | . as $i
      | (.timelineItems.nodes[0].closer // null) as $c
      | ( if $c == null then [] elif $c.__typename == "PullRequest" then [$c]
          else ($c.associatedPullRequests.nodes // []) end ) as $closers
      | ( [$i.comments.nodes[].body | select(evidence)] | length > 0 ) as $commented
      | if $i.stateReason == "NOT_PLANNED" then
          # the reason is a comment written within an hour before the close, or after it
          ( ($i.timelineItems.nodes[0].createdAt // "1970-01-01T00:00:00Z" | fromdateiso8601 - 3600) as $since
            | if any($i.comments.nodes[]; (.createdAt // "1970-01-01T00:00:00Z" | fromdateiso8601) >= $since) then empty
              else "#\($i.number): closed as not planned with no reason comment at the close" end )
        else
          ( $closers[] | select(has_tracking(.) and ((finishes(.) | index($i.number)) | not))
            | "#\($i.number): closed by PR #\(.number), whose Tracking block does not list it under Finishes" ),
          ( if ($c == null or $c.__typename == null) and ($commented | not)
              then "#\($i.number): closed with no linked PR and no evidence comment" else empty end )
        end ),
    # merged PRs whose Tracking block is not applied yet
    ( $prs[0][] | select(has_tracking(.)) | select((.body | test("(?im)^(Finishes|Progress|Evidence-only):[ \\t]*[^ \\t\\n]")))
      | ([.comments.nodes[].body | select(test("^Tracking applied"))] | last) as $marker
      | if $marker == null then "PR #\(.number): Tracking block not applied"
        elif ($marker | test("Unmatched:")) then "PR #\(.number): Tracking block not applied: the last marker lists Unmatched items"
        else empty end ),
    # umbrellas ready to close
    ( $issues[0][] | select(.state == "OPEN" and (.subIssuesSummary.total // 0) > 0
        and .subIssuesSummary.completed == .subIssuesSummary.total)
      | "#\(.number): all \(.subIssuesSummary.total) sub-issues are closed; close the umbrella" ),
    # comment lists cut off by the query
    ( $issues[0][] | select(.comments.totalCount > (.comments.nodes | length))
      | "#\(.number): more than \(.comments.nodes | length) comments; evidence check may be incomplete" )
')

status=$(jq -r -n --slurpfile issues "$work/issues.json" '
  $issues[0] as $all
  | ([$all[] | select(.state == "OPEN") | .milestone.title // empty | select(test("^Phase [0-9]"))] | sort | first) as $phase
  | ([$all[] | select(.milestone.title == $phase)]) as $in
  | ([$all[] | select(.state == "OPEN" and any(.labels.nodes[]; .name == "ingame-session"))] | sort_by(.number) | first) as $ig
  | [ (if $phase then "\($phase | split(" ")[0:2] | join(" ")) gate \([$in[] | select(.state == "CLOSED")] | length)/\($in | length) closed" else empty end),
      (if $ig then "next in-game: \($ig.title | split(":")[0]) #\($ig.number) (\([($ig.body // "") | split("\n")[] | select(test("^\\s*- \\[ \\]"))] | length) checks open)" else empty end)
    ] | join(", ")')

count=0
[[ -n $drift ]] && count=$(printf '%s\n' "$drift" | wc -l | tr -d ' ')
applied=$(printf '%s\n' "$drift" | grep -c 'Tracking block not applied')
line="Tracking: $count drift item(s)${applied:+, $applied PR(s) to apply}, $status"
line=${line/, 0 PR(s) to apply/}

if [[ $summary -eq 1 ]]; then
    echo "$line"
    [[ $count -gt 0 ]] && echo "  Run: bash tools/check-plan-index.sh (the track skill applies fixes)"
    [[ -z $data ]] && { mkdir -p "${cache%/*}" && echo "$(date '+%Y-%m-%d %H:%M') $line" >"$cache"; } 2>/dev/null
    exit 0
fi
[[ -n $drift ]] && printf '%s\n' "$drift"
echo "$line"
[[ $count -eq 0 ]]
