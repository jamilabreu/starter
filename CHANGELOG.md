# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-08-04

### Fixed

- Interactive `mix starter.run` (without `--yes`) stalled at the first
  `{:install, ...}` step: Igniter executes queued tasks through a
  subprocess with no stdin, so the upstream installer's confirmation
  prompt could never be answered. Queued tasks (installs included) now
  always run with `--yes` — confirming the workflow's diff is the
  approval for everything it queues.

## [0.1.0] - 2026-08-04

Initial release.

### Added

- `Starter.Workflow` — `use Starter.Workflow` turns a module into a runnable,
  flag-aware Igniter setup task
- Workflow step forms: built-in steps (`{:add, :oban}`), optional steps
  (`if: :flag`), arbitrary Mix tasks (`{:task, name, argv}`), nested workflows
  (`{:workflow, Module}`), and custom step modules
- `mix starter.new` — generates a self-documenting, editable workflow in your
  project. Every step carries a description rendered from its module's
  `@shortdoc`, so the file cannot drift from the catalog
- `mix starter.run` — finds and runs your project's workflow, passing flags
  through (equivalent to invoking the workflow task directly)
- `mix starter.add`, `mix starter.remove`, `mix starter.gen` — run steps
  individually, with `--list`
- `{:install, :package}` step form: packages that ship their own Igniter
  installer (oban, oban_web, tidewave, ash, …) are installed by their own
  installer via `mix igniter.install`; Starter ships no competing step for
  them. Built-in add steps exist only where upstream ships no installer.
- `{:queue, task, argv}` step form: queue any Mix task to run after the
  workflow's changes apply, in order — the way to sequence work after
  `{:install, ...}` steps (e.g. `oban_pro` after `{:install, :oban}`)
- `mix starter.new --from SomeShared.Workflow` — generate the app's workflow
  by expanding a shared workflow module (e.g. from a personal step pack)
  instead of the built-in catalog
- Step catalog: 11 add steps, 5 remove steps, 12 gen steps (see README)
- Latest-Phoenix-only support policy: steps target current `phx.new` output
  (Phoenix 1.8); workflows warn when run against apps on older Phoenix versions
- Remove/gen steps warn loudly when they find nothing to change instead of
  silently no-oping
- Version lookups (Hex, npm, GitHub, and the Oban Pro docs site for the
  private-repo `oban_pro` package) keep generated dependencies current and
  degrade gracefully offline
- Test suite built on `Igniter.Test`; CI golden test runs the generated
  workflow against a freshly generated `phx.new` app
