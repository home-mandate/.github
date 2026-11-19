#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# verify.sh TAG COMMIT checks, before anything is published, that a tag on a commit may become
# a release (RELEASING.md, "Publishing"), and prints what the release workflow needs:
#
#   version=X.Y.Z[-rc.N]   the tag without "v"
#   base=X.Y.Z             the version without a suffix; the version in the repository
#   kind=alpha|rc|version
#   prerelease=true|false
#   branch=main|release/X.Y
#
# 1. The tag is vX.Y.Z, vX.Y.0-alpha.N or vX.Y.Z-rc.N.
# 2. Where it stands: an alpha on main; a release candidate and a version on release/X.Y.
# 3. Where the commit came from: it is the merge commit of exactly one merged pull request,
#    into main or into that branch, and every check on the pull request's head passed.
#    REQUIRED_CHECKS names the checks that must be among them, by the beginning of their
#    names, one per line.
# 4. A version needs a release candidate of the same version on the same commit: published,
#    and with a run of the release workflow that succeeded, its release gate included. The
#    version is what was tested.
# 5. The release doesn't exist yet.
#
# Environment: GITHUB_REPOSITORY; GH_TOKEN with read access to contents, pull requests, checks
# and actions; REQUIRED_CHECKS; RELEASE_WORKFLOW (default: release.yml).
# Reads the remote-tracking branches and the tags of the current repository, so it needs the
# full history (fetch-depth: 0). Whatever cannot be read is a refusal.
set -euo pipefail

tag=${1:?usage: verify.sh TAG COMMIT}
commit=${2:?usage: verify.sh TAG COMMIT}
repo=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}
workflow=${RELEASE_WORKFLOW:-release.yml}

refuse() {
  echo "::error::$1" >&2
  exit 1
}

# api PATH FILTER prints the filtered answer. A failure is a refusal, except "not found" when
# the caller asks for it with NOT_FOUND=ok: then the status is 4 and nothing is printed.
api() {
  local out status=0
  out=$(gh api "$1" --paginate --jq "$2" 2> "$work/gh-error") || status=$?
  if [ "$status" -ne 0 ]; then
    if [ "${NOT_FOUND:-}" = ok ] && grep -q 'HTTP 404' "$work/gh-error"; then return 4; fi
    refuse "cannot read $1: $(tr '\n' ' ' < "$work/gh-error")"
  fi
  printf '%s' "$out"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

number='(0|[1-9][0-9]*)'
if ! [[ "$tag" =~ ^v$number\.$number\.$number(-(alpha|rc)\.$number)?$ ]]; then
  refuse "tag $tag is neither vX.Y.Z nor vX.Y.0-alpha.N nor vX.Y.Z-rc.N"
fi
minor="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
patch=${BASH_REMATCH[3]}
base="$minor.$patch"
kind=${BASH_REMATCH[5]:-version}
version=${tag#v}

[[ "$commit" =~ ^[0-9a-f]{40}$ ]] || refuse "$commit is not a commit"
git rev-parse --quiet --verify "$commit^{commit}" > /dev/null || refuse "commit $commit does not exist here"

# on BRANCH tells whether the commit is on the remote-tracking branch; a branch that does not
# exist has no commits.
on() {
  git rev-parse --quiet --verify "refs/remotes/origin/$1^{commit}" > /dev/null &&
    git merge-base --is-ancestor "$commit" "refs/remotes/origin/$1"
}

# 2. Where the tag stands.
if [ "$kind" = alpha ]; then
  [ "$patch" = 0 ] || refuse "$tag: an alpha belongs to a minor version, a patch has release candidates only"
  on main || refuse "$tag is an alpha and points to a commit that is not on main"
  branch=main
else
  on "release/$minor" || refuse "$tag points to a commit that is not on release/$minor"
  branch="release/$minor"
fi

# 3. Where the commit came from.
pulls=$(api "repos/$repo/commits/$commit/pulls" \
  ".[] | select(.merged_at != null and .merge_commit_sha == \"$commit\") | \"\(.number) \(.base.ref) \(.head.sha)\"")
if [ "$(grep -c . <<< "$pulls" || true)" != 1 ]; then
  refuse "$commit did not come from exactly one merged pull request"
fi
read -r pull pull_base head <<< "$pulls"
if [ "$pull_base" != main ] && [ "$pull_base" != "$branch" ]; then
  refuse "$commit came from pull request #$pull into $pull_base, not into main or $branch"
fi
[[ "$head" =~ ^[0-9a-f]{40}$ ]] || refuse "pull request #$pull has no head commit"

checks=$(api "repos/$repo/commits/$head/check-runs?per_page=100" '.check_runs[] | "\(.status)|\(.conclusion)|\(.name)"')
[ -n "$checks" ] || refuse "no check ran on the head of pull request #$pull"
printf '%s\n' "$checks" >&2
while IFS= read -r required; do
  [ -n "$required" ] || continue
  grep -qF -- "|$required" <<< "$checks" || refuse "check '$required' did not run on pull request #$pull"
done <<< "${REQUIRED_CHECKS:-}"
if grep -qvE '^completed\|(success|skipped|neutral)\|' <<< "$checks"; then
  refuse "not every check of pull request #$pull passed"
fi

# 4. A version is a release candidate that passed.
if [ "$kind" = version ]; then
  git tag --points-at "$commit" --list "v$base-rc.*" > "$work/candidates" || refuse "cannot list the tags on $commit"
  passed=""
  while IFS= read -r candidate; do
    [[ "$candidate" =~ ^v$number\.$number\.$number-rc\.$number$ ]] || continue
    status=0
    state=$(NOT_FOUND=ok api "repos/$repo/releases/tags/$candidate" '"\(.draft) \(.prerelease)"') || status=$?
    if [ "$status" -ne 0 ] || [ "$state" != "false true" ]; then
      echo "$candidate has no published release" >&2
      continue
    fi
    runs=$(api "repos/$repo/actions/workflows/$workflow/runs?event=push&head_sha=$commit&per_page=100" \
      ".workflow_runs[] | select(.head_branch == \"$candidate\") | \"\(.status) \(.conclusion)\"")
    if grep -qxF 'completed success' <<< "$runs"; then
      passed=$candidate
      break
    fi
    echo "$candidate: the run of $workflow is \"${runs:-missing}\"" >&2
  done < "$work/candidates"
  [ -n "$passed" ] ||
    refuse "$tag needs a release candidate v$base-rc.N on the same commit that is published and whose run of $workflow succeeded, its release gate included"
  echo "$tag is the release candidate $passed" >&2
fi

# 5. Not released yet.
status=0
NOT_FOUND=ok api "repos/$repo/releases/tags/$tag" .tag_name > /dev/null || status=$?
[ "$status" -eq 4 ] || refuse "release $tag exists already"

prerelease=true
[ "$kind" != version ] || prerelease=false
printf '%s\n' "version=$version" "base=$base" "kind=$kind" "prerelease=$prerelease" "branch=$branch"
