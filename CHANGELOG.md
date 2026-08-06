# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-08-06

Documentation fixes only — no behavior changes.

### Documentation

- `mix starter.add`'s own docs used `mix starter.add oban` as their example
  — the exact command 0.2.0's changelog called out as never working (`oban`
  has no built-in step). The examples now use built-in steps, and the
  moduledoc carries the README's note that the CLI runs Starter's own steps
  only.
- The `Starter` moduledoc still taught two retired patterns: the example
  starter composed `{:task, "igniter.install", ["ash"]}` where `{:add, :ash}`
  is the 0.2.0 story, and the `:queue` step form was illustrated with
  `{:queue, "starter.add", ["oban_pro"]}` — the pattern 0.2.1 scrubbed from
  the oban_pro warning.
- The README said `oban_pro` requires an existing `oban` dep; since 0.2.1
  the step checks for an existing Oban setup (its config), not the dep.
- `Starter.Versions` claimed lookups from Hex and npm; GitHub and the Oban
  Pro docs site were missing from the list.
- Consistency and wording: `mix starter.new --from` examples use
  `MyTeam.Starter` throughout, sharper shortdocs for the `gitignore` and
  `mix_env_config` steps, an untangled `generator_defaults` moduledoc, and
  small README and generated-starter wording fixes.

## [0.3.0] - 2026-08-06

### Changed

- **The thing you define is now called a *starter*, not a workflow**
  ([#2](https://github.com/jamilabreu/starter/issues/2)). "Workflow" is an
  overloaded term; "starter" is the library's own word, and now it is the
  API's word too:

    * `use Starter.Workflow` → `use Starter` — the behaviour moved into the
      top-level module (`@impl Starter`), and `Starter.Workflow.flags/1` and
      `flags_of/1` became `Starter.flags/1` and `Starter.flags_of/1`
    * `mix starter.new` generates `lib/mix/tasks/<app>.starter.ex` defining
      `Mix.Tasks.<App>.Starter`, runnable as `mix <app>.starter`
    * Including another starter's steps is `{:starter, SomeSharedStarter}`,
      previously `{:workflow, ...}`
    * `mix starter.run`'s discovery, docs, and error messages follow suit

  To upgrade an existing project, run `mix starter.new` again — or rename
  `lib/mix/tasks/<app>.workflow.ex` to `<app>.starter.ex` and update the
  module name, `use`/`@impl`, the `Code.ensure_loaded?` guard, and any
  `{:workflow, ...}` steps to match. Old generated files don't break the
  build — their `Code.ensure_loaded?(Starter.Workflow)` guard now compiles
  them to nothing — but `mix starter.run` won't find them until updated.

## [0.2.1] - 2026-08-06

All of these land on top of 0.2.0's single-verb change, and the first is
serious enough to make 0.2.0 worth skipping.

### Fixed

- **Migration versions could collide, leaving the app unmigratable.** Running
  with `--oban-pro` failed with `Ecto.MigrationError: migration version ... is
  duplicated`. Starter tracked its own migration timestamps but had no way to
  see one a package's installer created — fine in 0.1.x, where installers ran
  in a separate subprocess seconds later, but 0.2.0 made installers compose
  into the same run, where they can land in the same second. Timestamps are
  now advanced past every migration actually present, whoever wrote it.

- **The Tailwind class formatter never ran.** It guarded on
  `Code.ensure_loaded?(MyAppWeb.Formatters.ClassFormatter)`, but
  `.formatter.exs` is read before the project's code paths are set up, so that
  is `false` even after `mix compile` — `attribute_formatters` was always
  `%{}`. The generated file now requires the formatter source directly, which
  both fixes the sorting and makes formatting identical whether or not the app
  is built.

- The `oban_pro` step guarded on the `oban` *dependency*, which 0.2.0's
  in-run installs made meaningless: a workflow adds every package it installs
  to `mix.exs` before any step runs, so the check passed while `oban.install`
  had yet to compose.
  `{:add, :oban_pro}` placed before `{:add, :oban}` would proceed as if Oban
  were set up and write config for Oban's installer to clobber. It now checks
  for Oban's config — what `oban.install` actually writes — so it stays
  honest about ordering.

- The `oban_pro` warning still told users to reach for `{:install, :oban}`
  and `{:queue, "starter.add", ["oban_pro"]}`, the API 0.2.0 removed.

### Changed

- The `quokka` step adds `Quokka` to the `plugins` list in `.formatter.exs`
  itself instead of printing a notice telling you to. This needs the dep
  fetched before the plugin is named — `mix format` aborts on a plugin it
  cannot load — so the step now fetches as part of its work. It is appended
  rather than prepended, leaving `Phoenix.LiveView.HTMLFormatter` first.

- CI's golden test passes `--exsync --mix-test-watch --gigalixir`, so
  flag-gated steps are exercised against real `phx.new` output instead of
  never running. `--oban-pro` stays out: the package is licensed and lives in
  a private Hex repo, so that step is covered by unit tests only.

### Documentation

- Packages from private Hex repos or organizations need qualified names
  (`{:add, :"oban.oban_pro"}`). Bare names resolve against public Hex.

## [0.2.0] - 2026-08-05

### Changed

- **`{:add, name}` is now the single verb for getting a package into an
  app.** It runs Starter's built-in step when one exists, and otherwise
  installs the package and runs the package's own Igniter installer.
  Whether a package ships an installer is upstream's business and changes
  over time, so it is no longer something a workflow file has to encode —
  when a package gains an installer, its built-in step retires and
  workflows naming it keep working unchanged.

  `{:install, name}` still works, and now means "use upstream's installer
  even if Starter has a step of that name". It is rarely needed.

- **Package installers are composed into the workflow run** rather than
  queued into a subprocess. Everything a run does — Starter's steps and the
  packages' own installers — lands in one diff you confirm once. Installers
  no longer run after your confirmation via `mix igniter.install`.

  Dependencies are the exception: packages that resolve to an install are
  added to `mix.exs` and fetched before any step runs, because their
  installers have to be on disk to compose at all. That dependency change
  is shown and confirmed on its own, ahead of the run's main diff.

- **Steps apply in list order, installers included.** A step placed after
  one that installs a package sees its effects, so `{:queue, ...}` is no
  longer needed to sequence work around installs — it remains for work that
  genuinely has to run against the applied project on disk.

- The generated workflow follows suit: `oban_pro` and `sort_deps` are
  ordinary in-run steps again, `oban_pro` placed after `oban` whose
  installer output it patches, and `sort_deps` last so it sorts the
  dependencies the installers added. This supersedes the 0.1.2 change that
  queued `sort_deps`.

### Added

- Every run prints a plan showing what each step resolved to — a built-in
  step, a package's installer, a plain dependency, or queued work. This is
  where the built-in-vs-installer distinction is now visible, since the step
  list no longer draws it.

- `Starter.Runner.installs/2`, returning the packages a run would install
  with optional steps resolved against the given flags.

- `{:add, name}` raises with a suggestion when `name` closely resembles a
  built-in step, so a typo is reported as a typo instead of becoming a
  doomed Hex lookup.

### Fixed

- The README documented `mix starter.add oban,credo`, which never worked —
  `oban` has no built-in add step, so the command errored. The `starter.add`
  CLI runs Starter's own steps only; use `mix igniter.install` for packages
  that ship installers.

## [0.1.2] - 2026-08-04

### Fixed

- Passing a workflow flag (e.g. `mix starter.run --oban-pro`) crashed the
  entire queued-task chain: custom flags leaked into subprocess argv and
  `igniter.install`'s strict option parser rejected them, so no installs
  ran at all. Queued tasks now receive exactly their own args plus `--yes`.
- `mix starter.run` failed with "No workflow found" on Mix 1.20.3+:
  workflow discovery relied on `mix compile` loading the app, which newer
  Mix no longer does. The app is now loaded explicitly.
- Re-running the bun step on an already-configured app crashed rewrite's
  formatter; its dep add and config edits are now skip-on-rerun.

### Changed

- The generated workflow queues `sort_deps` last instead of running it
  in-run, so dependencies added by the `{:install, ...}` installers get
  sorted too. Ordering guidance added to the `Starter.Workflow` docs.

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
