#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# scope.sh RULES prints, as a JSON array, the scopes a change touches. The jobs of a workflow
# run only for their scope, so that a change to the changelog doesn't wait for the browser
# tests.
#
# What changed:
#   - FULL=true, or an event other than pull_request and push: everything, without a look at
#     the files (scheduled and manual runs, and the nightly full run).
#   - pull_request: the checked out merge commit against its first parent, the base branch.
#   - push to a branch: HEAD against the nearest of origin/main and origin/release/X.Y, the
#     branch this one was most likely started from. Needs the full history (fetch-depth: 0).
#   - push to main or release/X.Y itself: everything, there is nothing to compare with.
#
# The rules file:
#   scopes: go web                     every scope there is, once
#   PATTERN SCOPE... [only REGEX]      one rule per line, the first that matches a file counts
#
# PATTERN is matched against the whole path and "*" also matches "/" ("web/*" is everything
# under web/). SCOPE is a declared scope, "all", or "-" for none; a rule names at least one.
# With "only REGEX" the rule counts only if every added and every removed line of the file
# matches REGEX; otherwise the next rules are tried. A file that no rule matches touches every
# scope: what the rules don't know is checked in full.
#
# Whatever cannot be read or compared stops the script: a wrong "nothing changed" would skip
# checks.
set -euo pipefail

rules=${1:?usage: scope.sh RULES}

refuse() {
  echo "::error::$1" >&2
  exit 1
}

[ -f "$rules" ] || refuse "$rules does not exist"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mapfile -t all < <(sed -n 's/^scopes:[[:space:]]*//p' "$rules" | head -n 1 | tr -s '[:space:]' '\n' | sed '/^$/d')
[ "${#all[@]}" -gt 0 ] || refuse "$rules has no line \"scopes: …\""

emit() {
  jq -cn '$ARGS.positional | unique' --args "$@"
}

declared() {
  local scope
  for scope in "${all[@]}"; do
    [ "$scope" = "$1" ] && return 0
  done
  return 1
}

# nearest prints the merge base of HEAD and the nearest of origin/main and origin/release/X.Y.
nearest() {
  local best="" distance="" ref base count
  while read -r ref; do
    [[ "$ref" =~ ^refs/remotes/origin/(main|release/[0-9]+\.[0-9]+)$ ]] || continue
    base=$(git merge-base "$ref" HEAD 2> /dev/null) || continue
    count=$(git rev-list --count "$base..HEAD")
    if [ -z "$best" ] || [ "$count" -lt "$distance" ]; then
      best=$base
      distance=$count
    fi
  done < <(git for-each-ref --format='%(refname)' refs/remotes/origin/main 'refs/remotes/origin/release/*')
  [ -n "$best" ] || refuse "no origin/main and no origin/release/X.Y to compare with (fetch-depth: 0 is needed)"
  echo "$best"
}

# only_lines PATH REGEX tells whether every changed line of the file matches the expression.
# Files, not variables: a command substitution would drop empty lines at the end.
only_lines() {
  local status=0
  git --literal-pathspecs diff -U0 --no-renames "$base" HEAD -- "$1" > "$work/diff" ||
    refuse "cannot compare $1 with $base"
  awk 'hunk && /^[+-]/ { print substr($0, 2) } /^@@/ { hunk = 1 }' "$work/diff" > "$work/lines"
  [ -s "$work/lines" ] || return 1
  grep -qvE -- "$2" "$work/lines" || status=$?
  case "$status" in
    0) return 1 ;; # a line that does not match
    1) return 0 ;; # every line matches
    *) refuse "$rules: \"only $2\" is not a valid expression" ;;
  esac
}

# scopes_of PATH prints the scopes of the first rule that matches, one per line.
scopes_of() {
  local path=$1 line pattern rest regex scope
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*(#|$) || "$line" =~ ^scopes: ]] && continue
    read -r pattern rest <<< "$line"
    regex=""
    if [[ "$rest" =~ ^(.*[[:space:]])?only[[:space:]]+(.+)$ ]]; then
      rest=${BASH_REMATCH[1]}
      regex=${BASH_REMATCH[2]}
    fi
    [ -n "${rest//[[:space:]]/}" ] || refuse "$rules: the rule for \"$pattern\" names no scope (\"-\" for none)"
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ "$path" == $pattern ]] || continue
    if [ -n "$regex" ] && ! only_lines "$path" "$regex"; then continue; fi
    for scope in $rest; do
      case "$scope" in
        -) ;;
        all) printf '%s\n' "${all[@]}" ;;
        *)
          declared "$scope" || refuse "$rules: scope \"$scope\" of \"$pattern\" is not declared"
          echo "$scope"
          ;;
      esac
    done
    return 0
  done < "$rules"
  printf '%s\n' "${all[@]}"
}

if [ "${FULL:-false}" = true ]; then
  echo "full run: every scope" >&2
  emit "${all[@]}"
  exit 0
fi

case "${GITHUB_EVENT_NAME:-}" in
  pull_request)
    git rev-parse --quiet --verify 'HEAD^2^{commit}' > /dev/null ||
      refuse "HEAD is not the merge commit of a pull request (check out the default ref of the event)"
    base=$(git rev-parse 'HEAD^1')
    ;;
  push)
    if [[ "${GITHUB_REF:-}" =~ ^refs/heads/(main|release/[0-9]+\.[0-9]+)$ ]]; then
      echo "push to ${GITHUB_REF#refs/heads/}: every scope" >&2
      emit "${all[@]}"
      exit 0
    fi
    base=$(nearest)
    ;;
  *)
    echo "event \"${GITHUB_EVENT_NAME:-}\": every scope" >&2
    emit "${all[@]}"
    exit 0
    ;;
esac

# Into a file first: the status of a command in "< <(…)" is lost, and a failed comparison
# would read as "nothing changed".
git diff --name-only --no-renames -z "$base" HEAD > "$work/changed" || refuse "cannot compare HEAD with $base"

found=()
while IFS= read -r -d '' path; do
  touched=$(scopes_of "$path")
  echo "$path: ${touched//$'\n'/ }" >&2
  [ -z "$touched" ] || mapfile -t -O "${#found[@]}" found <<< "$touched"
done < "$work/changed"

emit "${found[@]}"
