#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Tests of scope.sh: each case builds a small repository with a "remote" main, changes files
# on a branch and compares the scopes with what is expected.
set -euo pipefail

script=$(cd "$(dirname "$0")" && pwd)/scope.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org

rules() {
  cat << 'EOF'
# the rules of the tests
scopes: go web

*.md                      -
app/config.yaml           -        only ^version:
web/shared/vectors.json   go web
web/*                     web
*.go                      go
go.mod                    go
ci/*                      all
docs/*                    -  only ^(#|$)
notes/*                   go only ^#
broken/*                  -  only [
EOF
}

# repo NAME creates a repository with main at a first commit and origin/main pointing to it.
repo() {
  dir="$work/$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -q -b main
  mkdir -p app web/shared docs ci notes broken
  printf '# title\n' > notes/list
  echo 'x' > broken/file
  rules > scope.rules
  printf 'version: "0.1.0"\nports:\n  - 8765\n' > app/config.yaml
  echo 'package main' > main.go
  echo 'module example' > go.mod
  echo '# readme' > README.md
  echo '{}' > web/shared/vectors.json
  echo 'x' > web/app.ts
  echo 'x' > other.txt
  printf '# title\n' > docs/notes
  git add -A
  git commit -q -m first
  git update-ref refs/remotes/origin/main HEAD
}

commit() {
  git add -A
  git commit -q -m "$1"
}

# as_pull_request leaves HEAD at the merge commit of the current branch into main, as
# actions/checkout does for a pull request.
as_pull_request() {
  local head
  head=$(git rev-parse HEAD)
  git checkout -q --detach refs/remotes/origin/main
  git merge -q --no-ff -m merge "$head"
}

expect() {
  local name=$1 want=$2 got status=0
  shift 2
  got=$(env "$@" "$script" scope.rules 2> "$work/stderr") || status=$?
  if [ "$status" -ne 0 ]; then got="exit $status"; fi
  if [ "$got" = "$want" ]; then
    echo "ok    $name"
  else
    echo "FAIL  $name: want $want, got $got"
    sed 's/^/      /' "$work/stderr"
    failed=1
  fi
}

change() {
  git checkout -q -b "$1"
}

repo text-only
change work
echo 'more' >> README.md
mkdir -p deep/er
echo 'x' > deep/er/NOTES.md
commit text
as_pull_request
expect "pull request: only Markdown touches nothing" '[]' GITHUB_EVENT_NAME=pull_request

repo version-line
change work
sed -i 's/0\.1\.0/0.1.1/' app/config.yaml
commit version
as_pull_request
expect "pull request: only the version line touches nothing" '[]' GITHUB_EVENT_NAME=pull_request

repo other-line
change work
sed -i 's/0\.1\.0/0.1.1/; s/8765/9000/' app/config.yaml
commit ports
as_pull_request
expect "pull request: another line of the same file is checked in full" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo web-only
change work
echo 'y' > web/app.ts
commit web
as_pull_request
expect "pull request: a file of the UI" '["web"]' GITHUB_EVENT_NAME=pull_request

repo shared
change work
echo '{"a":1}' > web/shared/vectors.json
commit shared
as_pull_request
expect "pull request: the first matching rule counts" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo go-and-text
change work
echo 'package main // changed' > main.go
echo 'more' >> README.md
commit both
as_pull_request
expect "pull request: scopes of all files together" '["go"]' GITHUB_EVENT_NAME=pull_request

repo unknown
change work
echo 'y' > other.txt
commit unknown
as_pull_request
expect "pull request: a file without a rule is checked in full" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo all-scope
change work
echo 'x' > ci/workflow.yml
commit ci
as_pull_request
expect "pull request: the scope all" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo deleted
change work
git rm -q main.go
commit deleted
as_pull_request
expect "pull request: a deleted file counts" '["go"]' GITHUB_EVENT_NAME=pull_request

repo renamed
change work
git mv main.go README2.md
commit renamed
as_pull_request
expect "pull request: a renamed file counts under its old name too" '["go"]' GITHUB_EVENT_NAME=pull_request

repo only-with-empty-alternative
change work
printf '# title\n\n# more\n' > docs/notes
commit docs
as_pull_request
expect "pull request: only with an expression that matches the empty line" '[]' GITHUB_EVENT_NAME=pull_request

repo only-with-blank-line-at-the-end
change work
printf '# title\n# more\n\n' > notes/list
commit notes
as_pull_request
expect "pull request: an empty line at the end is a changed line too" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo only-with-invalid-expression
change work
echo 'y' > broken/file
commit broken
as_pull_request
expect "pull request: an invalid expression after only is refused" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo name-with-space
change work
echo 'y' > 'web/my file.ts'
printf 'package main // x\n' > 'cmd main.go'
commit names
as_pull_request
expect "pull request: file names with spaces" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo three-parents
change one
echo 'y' > web/app.ts
commit web
git checkout -q main
change two
echo 'package main // two' > main.go
commit go
git checkout -q --detach refs/remotes/origin/main
git merge -q --no-ff -m merge one two > /dev/null
expect "pull request: a merge of more than two commits" '["go","web"]' GITHUB_EVENT_NAME=pull_request

repo unreadable-base
change work
echo 'y' > web/app.ts
commit web
as_pull_request
tree=$(git rev-parse 'HEAD^1^{tree}')
rm -f ".git/objects/${tree:0:2}/${tree:2}"
expect "pull request: a base that cannot be read is refused" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo not-a-merge
change work
echo 'y' > web/app.ts
commit web
expect "pull request: refuses a checkout that is not the merge commit" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo push-from-main
change work
echo 'y' > web/app.ts
commit web
expect "push: against main" '["web"]' GITHUB_EVENT_NAME=push

repo push-main-moved
change work
echo 'more' >> README.md
commit text
git checkout -q main
echo 'package main // main moved on' > main.go
commit "main moves on"
git update-ref refs/remotes/origin/main HEAD
git checkout -q work
expect "push: what main got meanwhile does not count" '[]' GITHUB_EVENT_NAME=push

repo push-from-release
git checkout -q -b release/0.1
echo 'package main // only on the release branch' > main.go
commit "a fix on the release branch"
git update-ref refs/remotes/origin/release/0.1 HEAD
git checkout -q main
echo 'z' > web/app.ts
commit "main moves on"
git update-ref refs/remotes/origin/main HEAD
git checkout -q -b backport release/0.1
echo 'more' >> README.md
commit "text on the release branch"
expect "push: against the nearest branch, here release/0.1" '[]' GITHUB_EVENT_NAME=push

repo push-ignores-other-branches
git checkout -q -b release/v0.1.1
git update-ref refs/remotes/origin/release/v0.1.1 HEAD
git checkout -q main
change work
echo 'y' > web/app.ts
commit web
git update-ref -d refs/remotes/origin/main
expect "push: without origin/main and release/X.Y there is nothing to compare with" 'exit 1' GITHUB_EVENT_NAME=push

repo push-to-main
echo 'more' >> README.md
commit text
git update-ref refs/remotes/origin/main HEAD
expect "push: to main itself is checked in full" '["go","web"]' GITHUB_EVENT_NAME=push GITHUB_REF=refs/heads/main

repo push-to-release
git checkout -q -b release/0.1
echo 'more' >> README.md
commit text
git update-ref refs/remotes/origin/release/0.1 HEAD
expect "push: to a release branch itself is checked in full" '["go","web"]' GITHUB_EVENT_NAME=push GITHUB_REF=refs/heads/release/0.1

repo push-no-change
change work
expect "push: a branch without a change touches nothing" '[]' GITHUB_EVENT_NAME=push

repo full
change work
echo 'more' >> README.md
commit text
expect "full: everything, whatever changed" '["go","web"]' GITHUB_EVENT_NAME=push FULL=true

repo schedule
expect "another event: everything" '["go","web"]' GITHUB_EVENT_NAME=schedule

repo undeclared
change work
{ echo 'scopes: go web'; echo 'web/*  ui'; } > scope.rules
echo 'y' > web/app.ts
commit undeclared
as_pull_request
expect "a rule with an undeclared scope is refused" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo rule-without-scope
change work
{ echo 'scopes: go web'; echo 'web/*'; } > scope.rules
echo 'y' > web/app.ts
commit no-scope
as_pull_request
expect "a rule that names no scope is refused" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo crlf
change work
printf 'scopes: go web\r\nweb/*  web\r\n' > scope.rules
echo 'y' > web/app.ts
commit crlf
as_pull_request
expect "rules with Windows line endings are refused" 'exit 1' GITHUB_EVENT_NAME=pull_request

repo no-scopes-line
echo 'web/*  web' > scope.rules
expect "rules without the scopes line are refused" 'exit 1' GITHUB_EVENT_NAME=schedule

repo no-rules
rm scope.rules
expect "missing rules are refused" 'exit 1' GITHUB_EVENT_NAME=schedule

exit "$failed"
