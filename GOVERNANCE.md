# Governance

Home-Mandate is small: I started it, and others work on parts of it. This page says who
decides what, so that nobody has to guess. It applies to every repository in the
`home-mandate` organization.

## Roles

**Owner (Markus Mazurczak).** I own the organization, the name and the logo
([TRADEMARKS.md](https://github.com/home-mandate/.github/blob/main/TRADEMARKS.md)), and I edit the specification until v1.0. I
decide:

- what goes into the specification, the schemas and the conformance cases;
- which repositories exist in the organization, what they are called and who maintains
  them;
- what is listed on [home-mandate.org](https://home-mandate.org).

**Maintainer of a repository.** Every repository has a named maintainer; for the
repositories I started, that is me. A maintainer decides everything inside their
repository: code, architecture, dependencies, style, releases and which contributions are
merged. I do not overrule a maintainer there. What a maintainer must keep is in
[IMPLEMENTATIONS.md](https://github.com/home-mandate/.github/blob/main/IMPLEMENTATIONS.md).

**Contributors.** Anyone may open issues, discussions and pull requests in any repository
([CONTRIBUTING.md](https://github.com/home-mandate/.github/blob/main/CONTRIBUTING.md)).

## How decisions are made

- Everything that touches more than one repository is decided in public: an issue or a
  discussion in the repository it belongs to. Changes to the specification are decided in
  pull requests in [spec](https://github.com/home-mandate/spec).
- **The specification is the truth.** If two implementations disagree, the text decides.
  If the text is unclear, that is a fault of the specification: it is clarified in the
  text, a conformance case is added, and then the implementations follow. A disagreement
  is never settled in one implementation's code.
- Implementers are heard before an incompatible change to the specification.
- If a maintainer and I disagree about something that is not inside their repository, I
  decide, and I say why in the issue.

## Later

The specification lives in its own repository, separate from any product, so that it can
be handed to a neutral body once more than one independent implementation exists. How
that works, and how the vocabulary and extensions are governed, is defined before v1.0.

## Changes to this page

By pull request in this repository. Changes that affect maintainers are announced to them
before the merge.
