# Releasing

How versions are planned, tested and published in the `home-mandate` organization. These
rules apply to every public repository that publishes versions, and they are not up to the
single repository. A repository's own `RELEASING.md` says only what is particular to it: what
it publishes and how it tests a version. `home-mandate.org` is deployed continuously and
publishes no versions, so it is not covered. A repository without a release yet follows these
rules from its first release on.

An implementation outside the organization doesn't have to follow them.
[IMPLEMENTATIONS.md](https://github.com/home-mandate/.github/blob/main/IMPLEMENTATIONS.md)
says what a conformance claim needs.

## Versions

Versions follow [Semantic Versioning](https://semver.org/). Before 1.0, a minor version
(`0.2.0`) brings new functions and may change behaviour; a patch version (`0.1.1`) only fixes.
Only the newest published minor version gets patches.

Before a version is published, pre-releases may be tagged on purpose: `vX.Y.Z-alpha.N` while
things are still moving, `vX.Y.Z-rc.N` for what should become the version. A merge doesn't
need a tag.

Every planned version has a milestone named after it (`v0.2`, without a date), and a patch
milestone (`v0.1.1`) is created when a fix for a published version is due. The same names in
every repository make one search show everything that belongs to a version.

## From milestone to version

1. Every change goes through a pull request with all checks green.
2. When the milestone's issues are done, publish a release candidate from `main` and test it
   as a user would.
3. Findings become issues in the milestone. Continue with step 1.
4. A pull request sets the version and adds the changelog entry. Publish the version from its
   commit.

A release candidate is the normal way. For small changes after one it can be skipped: the
changes, the version and the changelog then go through one pull request, tested before the
merge. This never applies to a release that changes the release workflow, because a published
tag can't be used twice.

## Fixes

- When a version `vX.Y.0` is published, a branch `release/X.Y` is created from its tag. Every
  patch `vX.Y.Z` comes from that branch.
- A fix goes to `main` first, through a pull request that closes the issue. A second pull
  request, titled `fix(X.Y): …` and linking the first, cherry-picks it into `release/X.Y`.
- If the bug no longer exists on `main`, the fix goes straight to `release/X.Y`, and that pull
  request says why.
- `release/X.Y` takes fixes only, plus the version and changelog of the patch. Functions never
  go there.
- A change to the release workflow, or to the checks it relies on, goes to the newest
  `release/X.Y` too, through a pull request titled `ci(X.Y): …`. The workflow runs in the
  version of the tagged commit, so a patch would otherwise be published the old way.
- `release/X.Y` is never merged back. After a patch, a pull request adds its changelog entry
  to `main`, so that the changelog there stays complete.
- A security fix is prepared in a private
  [security advisory](https://docs.github.com/en/code-security/security-advisories) and becomes
  public together with the patch. It may shorten the test of a release candidate, never skip it.

## Publishing

A published version can't be taken back. So every repository has these guards:

- **A release workflow** checks before anything is published:
  - a minor version comes from `main`, a patch from its own `release/X.Y`, and nothing from
    anywhere else;
  - the commit came from a merged pull request into that branch whose checks all passed;
  - the tag matches the version in the repository;
  - the release doesn't exist yet.
- **Tags** are immutable. Only administrators and the repository's maintainer may create them.
- **`main` and `release/*`** have the same ruleset: pull request required, checks required, no
  force-push, no deletion. Only administrators may create a `release/*` branch.
- **Implementations** attach a conformance report with build provenance to every release. A
  release is created as a draft and published only when its report is attached, or it is
  created in one step that attaches the report before the release is visible.
- **Published releases** are immutable (repository setting): no file can be added, replaced
  or removed afterwards, and the tag stays where it is. A run that fails before publishing
  needs a new version.
- **The nightly vulnerability check** also covers the newest `release/X.Y`. A release branch
  gets no dependency updates of its own, so a finding there is fixed like any other bug.

Create a tag with git, not with GitHub's "Draft a new release" page, which creates the release
together with the tag.
