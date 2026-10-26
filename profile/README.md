<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/home-mandate/.github/main/profile/assets/hm-lockup-dark.svg">
  <img src="https://raw.githubusercontent.com/home-mandate/.github/main/profile/assets/hm-lockup.svg" alt="Home-Mandate – AI is coming home. Decide what it may do." width="400">
</picture>

Home-Mandate lets every household decide what an AI agent may do – allow, ask or
deny – before anything happens. Every agent gets its own mandate: single actions,
limits, times of day, a confirmation on your phone and a tamper-evident log.

| Repository | What it is | License |
|---|---|---|
| [spec](https://github.com/home-mandate/spec) | The Home-Mandate Specification: data model, evaluation rule, vocabulary, JSON schemas, conformance cases and test tool; reference evaluator in Go | CC BY 4.0 (text), Apache 2.0 |
| [spec-ts](https://github.com/home-mandate/spec-ts) | Independent TypeScript implementation of the specification | Apache 2.0 |
| [ha-home-mandate](https://github.com/home-mandate/ha-home-mandate) | Home-Mandate for Home Assistant: the gateway that enforces mandates in front of Home Assistant | AGPL-3.0-or-later |
| [relay](https://github.com/home-mandate/relay) | Relay for Home-Mandate Cloud: makes a gateway at home reachable for cloud agents without opening ports; TLS ends at home, the relay only forwards encrypted bytes (in development) | AGPL-3.0-or-later |
| [home-mandate.org](https://github.com/home-mandate/home-mandate.org) | Source of the website [home-mandate.org](https://home-mandate.org) | Apache 2.0, CC BY 4.0 (texts) |

**Start here:** [home-mandate.org](https://home-mandate.org) explains mandates in plain
words · the [playground](https://home-mandate.org/playground/) runs in your browser ·
implementers start with the [specification](https://home-mandate.org/spec/v0/).

The specification is open and vendor-neutral: any product can implement it and prove
its conformance with the public test suite.

**Security:** please report vulnerabilities privately through GitHub's
"Report a vulnerability" in the affected repository.

"Home-Mandate" is a trademark filed with the German Patent and Trade Mark Office
(DPMA, application 302026256047.4). The logo is © 2026 Markus Mazurczak.
