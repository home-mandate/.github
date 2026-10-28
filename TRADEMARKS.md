# Name and logo

The specification and its code are open (CC BY 4.0 and Apache 2.0). The name
**Home-Mandate** and its logo are not: they are not covered by these licenses. This page
says how others may use them.

The goal is simple. Anyone may implement Home-Mandate, in any language and for any
platform, and an implementation that does what the specification says should be able to
show it. The name stands for a security property: agents act only within a mandate, and
anything unclear is denied. It must therefore only appear on software that keeps that
promise.

“Home-Mandate” has been filed as a word mark with the German Patent and Trade Mark Office
(DPMA, file number 30 2026 256 047.4). The logo (house with key) is © 2026 Markus
Mazurczak. Both belong to me, Markus Mazurczak.

## 1. Allowed without asking

You may use the name **in text, to describe facts**, without approval:

- “implements the Home-Mandate Specification v0.1.0, classes `evaluator` and `selection`”,
  if the implementation passes these classes (SPEC-v0 Section 8.1);
- in articles, talks, documentation, comparisons and links to this specification or to my
  implementations;
- in the name of a test, a module or a function inside your code, for example
  `home_mandate_evaluator`.

The use must not suggest that I made, checked or endorse your software unless I approved it
(Section 2).

## 2. Allowed with my approval

An implementation of the specification may use the name **in its product or package name**
and show the **compatibility mark** if I approved it. This applies to libraries (for example
an evaluator in Java or Python) and to gateways and integrations for a platform (for example
for openHAB or ioBroker).

**What is needed** – in a public issue in
[this repository](https://github.com/home-mandate/.github/issues):

1. **The conformance report** of `mandate-conformance` (SPEC-v0 Section 8.1): version, classes
   and manifest. Required classes:
   - a library: at least `evaluator`;
   - a gateway or integration, that is software through which agents act on a platform:
     `evaluator`, `selection`, `audit` and `pdp`;
   - in addition, whatever accepts mandates signed by another issuer: `signatures`.
2. **For a gateway or integration:** a statement for each item of SPEC-v0 Section 11 of how
   the implementation meets it (these duties cannot be tested from outside).
3. **The name** you want to use and who maintains the project.

**Names.** One of these forms, with the project's own part distinguishable from mine:

- `Home-Mandate for <platform>`, for example “Home-Mandate for openHAB”;
- `home-mandate-<language or purpose>` for packages, for example `home-mandate-python`.

Each name is approved once. If two projects want the same name, the first complete request
gets it. The description of the project says who maintains it, for example “maintained by
the openHAB community, not by the Home-Mandate project”, unless I maintain it myself.

**Compatibility mark.** Approved implementations may show the compatibility mark (the logo
with the words “Home-Mandate compatible”), unchanged, for example in their README, their
documentation or their entry in an add-on store. The files are in [`marks/`](marks/), for
light and dark backgrounds. Next to the mark, the implementation names the version of the
specification and the classes it passes, for example in the conformance section of its
README:

> Conforms to the Home-Mandate Specification `v0.1.0` in the classes `evaluator`,
> `selection`, `audit` and `pdp`.

My own implementations show the mark the same way. The logo alone stays reserved for my
own software.

**“Works with Home-Mandate”.** The second mark in [`marks/`](marks/) is for products that do
not implement the specification but work together with a Home-Mandate gateway, for
example an AI agent. It is not available yet: it will be once there is a test that shows
what it promises.

**What I approve.** I approve a request if the requirements above are met. I do not judge the
code otherwise. The approval is free of charge, not exclusive and not transferable, and I
confirm it in the issue. Approved implementations are listed on
[home-mandate.org](https://home-mandate.org).

## 3. When an approval ends

An approval applies to the version and classes it names. A project that supports a new
version of the specification sends a new report; until then it names the old version.

The approval ends, after notice and 30 days to remedy, if:

- the implementation no longer passes the classes it claims;
- a known security vulnerability stays unfixed for more than 90 days after it was reported;
- the name or the mark is used against this page.

The name and the mark are then removed within another 30 days. A project that is no longer
maintained may keep its name in archived releases.

## 4. Never allowed

- “Home-Mandate” alone, or with only a version number, as the name of software that is not
  mine;
- the logo, or anything confusingly similar, as the logo or icon of another product;
- modified versions of the name, the logo or the compatibility mark (other colours, shapes
  or words);
- the name in a company name or a domain name without my written approval;
- the name or the mark on software that does not pass the classes it claims, on a fork of my
  software that is changed, or on anything that suggests an endorsement I did not give.

Forks of my own software (for example `ha-home-mandate`, AGPL-3.0) may be passed on
unchanged under their name. A changed fork needs its own name and logo.

## 5. Questions

Not sure whether a use is allowed? Ask in an issue before using it. Exceptions are possible,
in writing.

This page does not limit what the law allows anyway, for example naming the specification to
describe what software does (Section 23 of the German Trade Mark Act).
