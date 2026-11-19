#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests of verify.sh. One repository with the branches of a real one, and a stand-in for gh
# that answers from files: each case says which pull requests, checks, releases and workflow
# runs GitHub knows, and what verify.sh must print or refuse.
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/verify.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
export GITHUB_REPOSITORY=example/project

# The stand-in: gh api PATH [--paginate] [--jq FILTER]. PATH names a file in $FIXTURES; a
# file that is missing answers "not found", a file PATH.error fails with its content.
mkdir -p "$work/bin"
cat > "$work/bin/gh" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = api ] || { echo "gh stand-in: only api, got $1" >&2; exit 2; }
shift
path="" filter="."
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter=$2; shift 2 ;;
    --paginate) shift ;;
    *) path=$1; shift ;;
  esac
done
file="$FIXTURES/$(printf '%s' "$path" | tr -c 'A-Za-z0-9.-' '_')"
if [ -f "$file.error" ]; then cat "$file.error" >&2; exit 1; fi
if [ ! -f "$file" ]; then echo "gh: Not Found (HTTP 404)" >&2; exit 1; fi
jq -r "$filter" "$file"
EOF
chmod +x "$work/bin/gh"
export PATH="$work/bin:$PATH"

fixture() {
  printf '%s/%s' "$FIXTURES" "$(printf '%s' "$1" | tr -c 'A-Za-z0-9.-' '_')"
}

# The repository:
#
#   root -- cut -- later                       main
#     \       \
#      \       fix                             release/0.2 (started at "cut")
#       old                                    release/0.1
#   root -- stray                              fix/other
cd "$work"
git init -q -b main repo
cd repo
commit() {
  git commit -q --allow-empty -m "$1"
  git rev-parse HEAD
}
root=$(commit root)
cut=$(commit cut)
later=$(commit later)
git update-ref refs/remotes/origin/main "$later"
git checkout -q -b release-02 "$cut"
fix=$(commit fix)
git update-ref refs/remotes/origin/release/0.2 "$fix"
git checkout -q -b release-01 "$root"
old=$(commit old)
git update-ref refs/remotes/origin/release/0.1 "$old"
git checkout -q -b other "$root"
stray=$(commit stray)
git update-ref refs/remotes/origin/fix/other "$stray"
git checkout -q main

head_of() { # the head commit of the pull request a commit came from, made up
  printf '%s' "$1" | tr '0-9a-f' 'f0-9a-e'
}

# world resets what GitHub knows: every commit came from its own merged pull request into
# its branch, with two green checks.
world() {
  FIXTURES="$work/fixtures"
  export FIXTURES
  rm -rf "$FIXTURES"
  mkdir -p "$FIXTURES"
  git tag -l | xargs -r git tag -d > /dev/null
  pull "$cut" 1 main
  pull "$later" 2 main
  pull "$fix" 3 release/0.2
  pull "$old" 4 release/0.1
  pull "$stray" 5 main
  local c
  for c in "$cut" "$later" "$fix" "$old" "$stray"; do
    checks "$c" 'completed|success|Go (vet, tests)' 'completed|skipped|Fuzz (short)'
  done
}

# pull COMMIT NUMBER BASE [MERGE_COMMIT] [MERGED_AT]
pull() {
  jq -n --arg n "$2" --arg base "$3" --arg head "$(head_of "$1")" --arg merge "${4:-$1}" --arg at "${5-2026-11-19T10:00:00Z}" \
    '[{number: ($n | tonumber), base: {ref: $base}, head: {sha: $head}, merge_commit_sha: $merge,
       merged_at: (if $at == "" then null else $at end)}]' > "$(fixture "repos/$GITHUB_REPOSITORY/commits/$1/pulls")"
}

# checks COMMIT 'status|conclusion|name'...
checks() {
  local commit=$1
  shift
  printf '%s\n' "$@" | jq -R 'split("|") | {status: .[0], conclusion: (if .[1] == "" then null else .[1] end), name: .[2]}' |
    jq -s '{check_runs: .}' > "$(fixture "repos/$GITHUB_REPOSITORY/commits/$(head_of "$commit")/check-runs?per_page=100")"
}

# release TAG DRAFT PRERELEASE
release() {
  jq -n --arg tag "$1" --argjson draft "$2" --argjson pre "$3" '{tag_name: $tag, draft: $draft, prerelease: $pre}' \
    > "$(fixture "repos/$GITHUB_REPOSITORY/releases/tags/$1")"
}

# runs COMMIT 'tag status conclusion [id]'...: without an id the run is 100, and its jobs
# are those of a release candidate that passed.
runs() {
  local commit=$1
  shift
  printf '%s\n' "$@" | jq -R 'split(" ") | {id: ((.[3] // "100") | tonumber), head_branch: .[0], status: .[1], conclusion: (.[2] // null)}' |
    jq -s '{workflow_runs: .}' \
      > "$(fixture "repos/$GITHUB_REPOSITORY/actions/workflows/release.yml/runs?event=push&head_sha=$commit&per_page=100")"
  jobs 100 'success|Check the tag' 'success|Publish the release' 'success|Release gate'
}

# jobs RUN 'conclusion|name'...
jobs() {
  local run=$1
  shift
  printf '%s\n' "$@" | jq -R 'split("|") | {conclusion: .[0], name: .[1]}' | jq -s '{jobs: .}' \
    > "$(fixture "repos/$GITHUB_REPOSITORY/actions/runs/$run/jobs?per_page=100")"
}

# candidate TAG COMMIT: a release candidate that passed.
candidate() {
  git tag "$1" "$2"
  release "$1" false true
  runs "$2" "$1 completed success"
}

# expect NAME WANT TAG COMMIT: WANT is "refused" or the output on one line.
expect() {
  local name=$1 want=$2 got status=0
  got=$(REQUIRED_CHECKS=${REQUIRED-$'Go (\nFuzz ('} "$script" "$3" "$4" 2> "$work/stderr" | tr '\n' ' ') || status=$?
  got=${got% }
  if [ "$status" -ne 0 ]; then
    got=refused
    grep -q '^::error::' "$work/stderr" || got="refused without an annotation"
  fi
  if [ "$got" = "$want" ]; then
    echo "ok    $name"
  else
    echo "FAIL  $name: want \"$want\", got \"$got\""
    sed 's/^/      /' "$work/stderr"
    failed=1
  fi
}

rc='version=0.2.0-rc.1 base=0.2.0 kind=rc prerelease=true branch=release/0.2'

# Tags.
world
for bad in v0.2 0.2.0 v0.2.0-beta.1 'v0.2.0-rc.1;x' $'v0.2.0\nv0.2.1' v00.2.0 v0.2.0-rc.01 v0.2.0-rc v0.2.0-; do
  expect "tag: ${bad//$'\n'/ } is not a version" refused "$bad" "$fix"
done
expect "commit: not a commit" refused v0.2.0-rc.1 main
expect "commit: unknown here" refused v0.2.0-rc.1 0123456789012345678901234567890123456789

# An alpha comes from main.
world
expect "alpha: on main" 'version=0.3.0-alpha.1 base=0.3.0 kind=alpha prerelease=true branch=main' v0.3.0-alpha.1 "$later"
expect "alpha: not from a release branch" refused v0.2.0-alpha.1 "$fix"
expect "alpha: not of a patch" refused v0.2.1-alpha.1 "$later"
expect "alpha: not from anywhere else" refused v0.3.0-alpha.1 "$stray"

# A release candidate comes from its release branch.
world
expect "rc: on its release branch" "$rc" v0.2.0-rc.1 "$fix"
expect "rc: on the commit the branch started from, merged into main" "$rc" v0.2.0-rc.1 "$cut"
expect "rc: of a patch" 'version=0.2.3-rc.2 base=0.2.3 kind=rc prerelease=true branch=release/0.2' v0.2.3-rc.2 "$fix"
expect "rc: not from main after the branch started" refused v0.2.0-rc.1 "$later"
expect "rc: not from another release branch" refused v0.2.0-rc.1 "$old"
expect "rc: not without its release branch" refused v0.3.0-rc.1 "$later"
expect "rc: not from anywhere else" refused v0.2.0-rc.1 "$stray"

# Where the commit came from.
world
rm "$(fixture "repos/$GITHUB_REPOSITORY/commits/$fix/pulls")"
expect "pull request: none known" refused v0.2.0-rc.1 "$fix"
world
echo '[]' > "$(fixture "repos/$GITHUB_REPOSITORY/commits/$fix/pulls")"
expect "pull request: none" refused v0.2.0-rc.1 "$fix"
world
pull "$fix" 3 release/0.2 "$stray"
expect "pull request: the commit is in it, but is not its merge commit" refused v0.2.0-rc.1 "$fix"
world
pull "$fix" 3 release/0.2 "$fix" ""
expect "pull request: not merged" refused v0.2.0-rc.1 "$fix"
world
pull "$fix" 3 release/0.1
expect "pull request: into another release branch" refused v0.2.0-rc.1 "$fix"
world
pull "$fix" 3 feature/x
expect "pull request: into a feature branch" refused v0.2.0-rc.1 "$fix"
world
file=$(fixture "repos/$GITHUB_REPOSITORY/commits/$fix/pulls")
jq '. + [.[0] | .number = 9]' "$file" > "$file.new" && mv "$file.new" "$file"
expect "pull request: two" refused v0.2.0-rc.1 "$fix"
world
pull "$later" 2 release/0.2
expect "pull request: an alpha's must be into main" refused v0.3.0-alpha.1 "$later"
world
echo 'gh: Server Error (HTTP 502)' > "$(fixture "repos/$GITHUB_REPOSITORY/commits/$fix/pulls").error"
expect "pull request: GitHub does not answer" refused v0.2.0-rc.1 "$fix"

# Its checks.
world
checks "$fix" 'completed|success|Go (vet, tests)' 'completed|failure|Fuzz (short)'
expect "checks: one failed" refused v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|success|Go (vet, tests)' 'in_progress||Fuzz (short)'
expect "checks: one is still running" refused v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|success|Go (vet, tests)' 'completed|cancelled|Fuzz (short)'
expect "checks: one was cancelled" refused v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|success|Go (vet, tests)'
expect "checks: a required one did not run" refused v0.2.0-rc.1 "$fix"
world
echo '{"check_runs": []}' > "$(fixture "repos/$GITHUB_REPOSITORY/commits/$(head_of "$fix")/check-runs?per_page=100")"
REQUIRED="" expect "checks: none at all" refused v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|success|Go (vet, tests)' 'completed|neutral|Fuzz (short)' 'completed|skipped|Web E2E'
expect "checks: skipped and neutral count as passed" "$rc" v0.2.0-rc.1 "$fix"
world
REQUIRED="" expect "checks: no required names is a mistake of the caller" refused v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|skipped|Go (vet, tests)' 'completed|skipped|Fuzz (short)' 'completed|success|Scope (push)'
expect "checks: a pull request of text alone skipped the required ones" "$rc" v0.2.0-rc.1 "$fix"
world
checks "$fix" 'completed|success|Lint, then Go (vet)' 'completed|success|Fuzz (short)'
expect "checks: the required text must begin the name" refused v0.2.0-rc.1 "$fix"
world
REQUIRED=success expect "checks: the required text is not looked for in the result" refused v0.2.0-rc.1 "$fix"
for conclusion in timed_out action_required stale; do
  world
  checks "$fix" 'completed|success|Go (vet, tests)' "completed|$conclusion|Fuzz (short)"
  expect "checks: $conclusion is not passed" refused v0.2.0-rc.1 "$fix"
done

# The tag and the versions that are out.
world
git tag v0.2.0-rc.1 "$cut"
expect "tag: exists on another commit" refused v0.2.0-rc.1 "$fix"
world
git tag v0.2.0-rc.1 "$fix"
expect "tag: exists on this commit" "$rc" v0.2.0-rc.1 "$fix"
world
git tag v0.2.1 "$fix"
expect "order: not behind a newer version" refused v0.2.0-rc.1 "$cut"
world
git tag v0.2.0 "$fix"
expect "order: no release candidate of a version that is out" refused v0.2.0-rc.2 "$fix"
world
git tag v0.2.0 "$fix"
expect "order: the next patch not on the commit of the last version" refused v0.2.1-rc.1 "$fix"
world
git tag v0.2.0 "$fix"
expect "order: the next patch not before the last version" refused v0.2.1-rc.1 "$cut"
world
git tag v0.2.0 "$cut"
expect "order: the next patch after the last version" 'version=0.2.1-rc.1 base=0.2.1 kind=rc prerelease=true branch=release/0.2' v0.2.1-rc.1 "$fix"
world
git tag v0.3.0 "$cut"
expect "order: no alpha of a version that is out" refused v0.3.0-alpha.1 "$later"

# A version is a release candidate that passed.
final='version=0.2.0 base=0.2.0 kind=version prerelease=false branch=release/0.2'
world
candidate v0.2.0-rc.1 "$fix"
expect "version: on the commit of a release candidate that passed" "$final" v0.2.0 "$fix"
world
expect "version: no release candidate" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$cut"
expect "version: the release candidate is on another commit" refused v0.2.0 "$fix"
world
candidate v0.2.1-rc.1 "$fix"
expect "version: the release candidate is of another version" refused v0.2.0 "$fix"
world
git tag v0.2.0-rc.1 "$fix"
runs "$fix" 'v0.2.0-rc.1 completed success'
expect "version: the release candidate has no release" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
release v0.2.0-rc.1 true true
expect "version: the release candidate is a draft" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
runs "$fix" 'v0.2.0-rc.1 completed failure'
expect "version: the release candidate's run failed" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
runs "$fix" 'v0.2.0-rc.1 in_progress'
expect "version: the release candidate's run has not finished" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
runs "$fix" 'v0.2.0-rc.2 completed success'
expect "version: the run that succeeded is another tag's" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
rm "$(fixture "repos/$GITHUB_REPOSITORY/actions/workflows/release.yml/runs?event=push&head_sha=$fix&per_page=100")"
expect "version: no run known" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
jobs 100 'success|Check the tag' 'success|Publish the release' 'skipped|Release gate'
expect "version: the gate of the release candidate was skipped" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
jobs 100 'success|Check the tag' 'success|Publish the release' 'success|Release gate (part)'
expect "version: the run has no job with the gate's name" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
rm "$(fixture "repos/$GITHUB_REPOSITORY/actions/runs/100/jobs?per_page=100")"
expect "version: the jobs of the run cannot be read" refused v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
runs "$fix" 'v0.2.0-rc.1 completed failure 99' 'v0.2.0-rc.1 completed success 100'
expect "version: a second run of the release candidate passed" "$final" v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
git tag v0.2.0-rc.2 "$fix"
release v0.2.0-rc.2 false true
runs "$fix" 'v0.2.0-rc.1 completed failure 99' 'v0.2.0-rc.2 completed success'
expect "version: the second release candidate on the commit passed" "$final" v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
git tag -d v0.2.0-rc.1 > /dev/null
git tag -a -m annotated v0.2.0-rc.1 "$fix"
expect "version: an annotated tag counts" "$final" v0.2.0 "$fix"
world
candidate v0.2.0-rc.1 "$cut"
expect "version: on the commit the branch started from" "$final" v0.2.0 "$cut"

# Not released yet.
world
release v0.2.0-rc.1 false true
expect "release: exists already" refused v0.2.0-rc.1 "$fix"
world
echo 'gh: Server Error (HTTP 502)' > "$(fixture "repos/$GITHUB_REPOSITORY/releases/tags/v0.2.0-rc.1").error"
expect "release: GitHub does not answer" refused v0.2.0-rc.1 "$fix"
world
echo 'gh: upstream said (HTTP 404) while proxying (HTTP 502)' > "$(fixture "repos/$GITHUB_REPOSITORY/releases/tags/v0.2.0-rc.1").error"
expect "release: an error that mentions 404 is not \"not found\"" refused v0.2.0-rc.1 "$fix"


# What follows a release needs the release.
world
release v0.2.0-rc.1 false true
RELEASE_STATE=published expect "published: the release is out" "$rc" v0.2.0-rc.1 "$fix"
world
RELEASE_STATE=published expect "published: no release" refused v0.2.0-rc.1 "$fix"
world
release v0.2.0-rc.1 true true
RELEASE_STATE=published expect "published: the release is a draft" refused v0.2.0-rc.1 "$fix"
world
echo 'gh: Server Error (HTTP 502)' > "$(fixture "repos/$GITHUB_REPOSITORY/releases/tags/v0.2.0-rc.1").error"
RELEASE_STATE=published expect "published: GitHub does not answer" refused v0.2.0-rc.1 "$fix"
world
candidate v0.2.0-rc.1 "$fix"
release v0.2.0 false false
RELEASE_STATE=published expect "published: a version still needs its release candidate" "$final" v0.2.0 "$fix"
world
release v0.2.0 false false
RELEASE_STATE=published expect "published: a version without a release candidate" refused v0.2.0 "$fix"
world
RELEASE_STATE=draft expect "published: an unknown state is a mistake of the caller" refused v0.2.0-rc.1 "$fix"

exit "$failed"
