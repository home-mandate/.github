# Actions

What the workflows of the `home-mandate` repositories share, kept once. A workflow uses an
action pinned by commit:

```yaml
- uses: home-mandate/.github/actions/scope@<commit> # the commit on main
```

A change here reaches a repository only when a pull request there moves the pin. So a
workflow keeps running the version it was reviewed with, and a release runs the version of
the tagged commit ([RELEASING.md](../RELEASING.md)).

| Action | What it does |
|---|---|
| [`scope`](scope/) | Tells which scopes of a repository a change touches, from the rules in `.github/scope.rules`, so that the jobs of a workflow run only for what changed. The format of the rules is described in [`scope/scope.sh`](scope/scope.sh). |

Every action has its tests next to it (`test.sh`); `.github/workflows/ci.yml` runs them on
every push to a branch.

The files in this directory are licensed under Apache 2.0 ([LICENSE](LICENSE)).
