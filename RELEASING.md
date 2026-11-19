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

Before a version is published, pre-releases are tagged on purpose: `vX.Y.0-alpha.N` on `main`
while things are still moving, `vX.Y.Z-rc.N` for what should become the version. A merge
doesn't need a tag.

Every planned version has a milestone named after it (`v0.2`, without a date), and a patch
milestone (`v0.1.1`) is created when a fix for a published version is due. The same names in
every repository make one search show everything that belongs to a version.

## Branches

- **`main`** is where development happens. Everything new goes there, through a pull request.
- **`release/X.Y`** is created when the first release candidate of `X.Y.0` is due, and it stays:
  every release candidate, the version and every patch of `X.Y` are tagged there. It takes
  fixes only. While `X.Y` is being stabilized, `main` already belongs to the next version.

There is no other long-lived branch. A release branch is never merged back.

## A release is a tag

A release needs no commit of its own. The repository carries the version without a suffix
(`X.Y.Z`); the release workflow adds `-rc.N` from the tag when it builds a release candidate.
The changelog entry of `X.Y.Z` is written before its first release candidate.

So a release candidate and the version it becomes are the same commit, and the version is
what was tested: the tag `vX.Y.Z` goes on the commit of a release candidate that passed.
Nothing is changed and nothing is tested again in between.

A version always has a release candidate. That holds for a small patch and for a security fix
too: a release candidate costs a tag, not a pull request.

## From milestone to version

1. Every change goes through a pull request into `main` with all checks green.
2. When the milestone's issues are done, a pull request into `main` sets the version and turns
   "Unreleased" into the changelog entry of `X.Y.0`, without a date. `release/X.Y` is created
   from its commit.
3. Tag `vX.Y.0-rc.1` on `release/X.Y`. The release workflow publishes the release candidate
   and then runs the release gate on its commit (see "Checks follow the change"). Test it as a
   user would.
4. Findings become issues in the milestone. A fix goes to `main` first and then to
   `release/X.Y` (see "Fixes"); the next release candidate is tagged on the new commit.
5. When a release candidate has passed its gate and the test, tag `vX.Y.0` on the same commit.

A repository's own `RELEASING.md` says where step 2 differs for it.

## Fixes

- A fix goes to `main` first, through a pull request that closes the issue. A second pull
  request, titled `fix(X.Y): …` and linking the first, cherry-picks it into `release/X.Y`.
- If the bug no longer exists on `main`, the fix goes straight to `release/X.Y`, and that pull
  request says why.
- The first fix of a patch also sets the version `X.Y.Z` on `release/X.Y` and starts its
  changelog entry; further fixes add to the entry. Then the patch is released like any
  version: release candidate, gate and test, and the version on the same commit.
- `release/X.Y` takes fixes only. Functions never go there.
- A change to the release workflow, or to the checks it relies on, goes to the newest
  `release/X.Y` too, through a pull request titled `ci(X.Y): …`. The workflow runs in the
  version of the tagged commit, so a patch would otherwise be published the old way.
- After a patch, a pull request adds its changelog entry to `main`, so that the changelog
  there stays complete.
- A security fix is prepared in a private
  [security advisory](https://docs.github.com/en/code-security/security-advisories) and becomes
  public together with the patch. It may shorten the test of a release candidate by hand,
  never the release candidate or its gate.

## Releases that depend on each other

An implementation names the version of the specification it implements, and a repository may
require another one's module. What becomes a version names versions, not release candidates:

1. The specification publishes a release candidate.
2. The implementation publishes its own release candidate against it. What it finds goes
   back as issues.
3. The specification publishes its version.
4. A pull request moves the implementation to that version. A new release candidate follows,
   and the implementation's version goes on its commit.

## Checks follow the change

How expensive a check is decides where it runs.

- **A pull request** runs the jobs of what it touches. Each repository lists in
  `.github/scope.rules` which files belong to which scope; a change to the changelog doesn't
  wait for the browser tests. A skipped job counts as passed, and a file without a rule runs
  everything.
- **Every night**, every job runs on `main` if `main` changed, so rules that skip too much
  show the next morning. The same run checks the dependencies of `main` and of the newest
  `release/X.Y` for known vulnerabilities; while that branch has no version yet, also the
  branch before it. A release branch gets no dependency updates of its own, so a finding
  there is fixed like any other bug.
- **Fuzzing** keeps what it finds: a pull request replays the inputs earlier runs found and
  adds a few seconds per target, and twice a week every target runs longer and saves them.
- **A release candidate** runs the release gate: long fuzzing, and what tests the published
  artifact itself, such as an update from the previous version. A repository's own
  `RELEASING.md` lists its gate. These checks belong to a release, not to every merge and not
  to a date.

A failure of a scheduled run opens an issue.

## Publishing

A published version can't be taken back. So every repository has these guards:

- **A release workflow** checks before anything is published:
  - an alpha stands on `main`, a release candidate and a version on their `release/X.Y`, and
    nothing anywhere else;
  - the commit came from a merged pull request, into `main` or into that branch, whose checks
    all passed;
  - a version stands on the commit of a release candidate of the same version that is
    published and whose run of the release workflow succeeded, its gate included;
  - the tag matches the version in the repository;
  - the release doesn't exist yet.

  The first three and the last are the same code for every repository,
  [`actions/release-verify`](actions/release-verify/), pinned by commit.
- **A dry run** checks the same without a tag: run the release workflow by hand on the branch
  and name the tag it should check
  (`gh workflow run release.yml --ref release/X.Y -f tag=vX.Y.Z-rc.1`). It publishes nothing.
  Do it before every tag: a tag that fails the guards can't be used again.
- **Tags** are immutable. Only administrators and the repository's maintainer may create them.
- **`main` and `release/*`** have the same ruleset: pull request required, checks required, no
  force-push, no deletion. Only administrators may create a `release/*` branch.
- **Implementations** attach a conformance report with build provenance to every release. A
  release is created as a draft and published only when its report is attached, or it is
  created in one step that attaches the report before the release is visible.
- **Published releases** are immutable (repository setting): no file can be added, replaced
  or removed afterwards, and the tag stays where it is. A run that fails before publishing
  needs a new version.

Create a tag with git, not with GitHub's "Draft a new release" page, which creates the release
together with the tag.
