# Implementations

Anyone may implement the Home-Mandate Specification, in any language and for any platform,
inside this organization or anywhere else. This page is for implementations: libraries
such as [spec-ts](https://github.com/home-mandate/spec-ts), and bridges that enforce
mandates on a platform, such as
[ha-home-mandate](https://github.com/home-mandate/ha-home-mandate).

## Inside or outside the organization

- **Outside** is always fine and needs nobody's permission. The name and the logo follow
  [TRADEMARKS.md](https://github.com/home-mandate/spec/blob/main/TRADEMARKS.md).
- **Inside** the organization, a repository is created when I invite someone to maintain
  it, or when someone asks and I agree. The repository belongs to the organization; the
  maintainer runs it ([GOVERNANCE.md](GOVERNANCE.md)). Inside or outside, an
  implementation that passes the conformance suite is listed on
  [home-mandate.org](https://home-mandate.org) the same way.

## Names in the organization

| What | Repository | Example |
|---|---|---|
| Library in another language | `spec-<language>` | `spec-ts`, `spec-py` |
| Bridge for a platform | `<platform>-home-mandate` | `ha-home-mandate` |

The name of a published package (npm, PyPI, …) is agreed when the repository is created.

## Rights of a maintainer

- The **Maintain** role on their repository: merge, release, manage issues, discussions
  and settings that do not touch security.
- No rights on other repositories through this role.
- The CI workflows and the branch protection of `main` are reviewed by me
  (`CODEOWNERS`), so that the checks that make the conformance claim stay in place.

## What every implementation keeps

1. **Built from the specification.** An implementation is written from the text of the
   specification and its conformance cases, not ported from another implementation. That
   is what makes it worth having: it shows that the text alone is enough. Questions about
   the text go to [spec](https://github.com/home-mandate/spec/issues) as an issue; they
   often show a gap.
2. **Conformance is measured, not claimed.** The README names the version of the
   specification and the conformance classes the implementation passes (SPEC-v0 Section
   8.1). "Passes" means: `mandate-conformance` from the matching tag of the specification,
   run in CI on every change. I run it myself before an implementation is listed.
3. **Tests come from the specification.** Where a test checks behaviour the
   specification defines, it is derived from the text or the conformance cases, not from
   what the code happens to do. Signature verification, digests, canonicalization and the
   evaluation are reviewed by a person before they are merged.
4. **Scheduled checks.** Every repository checks its dependencies for known
   vulnerabilities every night. Every implementation that reads input from outside
   (mandates, requests, audit logs, signatures) also fuzzes those parsers for a long run
   on the 1st and 15th of every month. A failure opens an issue in the repository. The
   tools are the maintainer's choice.
5. **Security.** A `SECURITY.md` with GitHub's private vulnerability reporting turned on.
   Reports are answered as soon as possible, aiming for a week; if that is not possible
   for a while, the maintainer tells me, so that someone else can look at it. A flaw
   caused by the specification is reported to
   [spec](https://github.com/home-mandate/spec/security) as well.
6. **License.** Apache 2.0 for libraries. A bridge may use a copyleft license; it says so
   in its README.
7. **Honest results.** Conformance reports, test results and coverage come from real runs.

## What nobody owes

No deadlines, no feature list beyond the conformance classes an implementation claims,
and no support for users. Everyone here works on this in their own time.

## When someone stops

Anyone may stop maintaining a repository at any time; a short note in an issue is enough.
The repository is then archived or handed to a new maintainer. Nothing is deleted.

If an implementation no longer passes the classes it claims, or a reported vulnerability
stays unfixed for more than 90 days, I say so in an issue first. If nothing changes within
30 days, the listing on home-mandate.org is removed, and the README says that the
implementation is not maintained.
