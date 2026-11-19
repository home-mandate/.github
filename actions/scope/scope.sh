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
#   - push: HEAD against the nearest of origin/main and origin/release/X.Y, the branch this
#     one was most likely started from. Needs the full history (fetch-depth: 0).
#
# The rules file:
#   scopes: go web                     every scope there is, once
#   PATTERN SCOPE... [only REGEX]      one rule per line, the first that matches a file counts
#
# PATTERN is matched against the whole path and "*" also matches "/" ("web/*" is everything
# under web/). SCOPE is a declared scope, "all", or "-" for none. With "only REGEX" the rule
# counts only if every added and every removed line of the file matches REGEX; otherwise the
# next rules are tried. A file that no rule matches touches every scope: what the rules don't
# know is checked in full.
set -euo pipefail

rules=${1:?usage: scope.sh RULES}

refuse() {
  echo "::error::$1" >&2
  exit 1
}

[ -f "$rules" ] || refuse "$rules does not exist"

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
only_lines() {
  local lines
  lines=$(git diff -U0 --no-renames "$base" HEAD -- "$1" | awk 'hunk && /^[+-]/ { print substr($0, 2) } /^@@/ { hunk = 1 }')
  [ -n "$lines" ] && ! grep -qvE -- "$2" <<< "$lines"
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
    base=$(nearest)
    ;;
  *)
    echo "event \"${GITHUB_EVENT_NAME:-}\": every scope" >&2
    emit "${all[@]}"
    exit 0
    ;;
esac

found=()
while IFS= read -r -d '' path; do
  touched=$(scopes_of "$path")
  echo "$path: ${touched//$'\n'/ }" >&2
  [ -z "$touched" ] || mapfile -t -O "${#found[@]}" found <<< "$touched"
done < <(git diff --name-only --no-renames -z "$base" HEAD)

emit "${found[@]}"
