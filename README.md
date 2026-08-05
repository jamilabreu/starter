# Starter

> Your Phoenix starting point, as a workflow.

[![CI](https://github.com/jamilabreu/starter/actions/workflows/ci.yml/badge.svg)](https://github.com/jamilabreu/starter/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/starter.svg)](https://hex.pm/packages/starter)
[![Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/starter)

Every new Phoenix app begins the same way: run `mix phx.new`, then spend an
hour undoing defaults you don't want and wiring in the packages you always
use. **Starter** turns that hour into a *workflow* — an ordered, flag-aware
list of steps that lives in your project — built on
[Igniter](https://hexdocs.pm/igniter), so every change is applied as a
reviewable patch rather than a blind file overwrite.

Your workflow is a plain module in your own project — generated for you by
`mix starter.new`, then edited to taste:

```elixir
defmodule Mix.Tasks.MyApp.Workflow do
  use Starter.Workflow

  @impl Starter.Workflow
  def steps do
    [
      {:remove, :daisy_ui},                  # undo a phx.new default
      {:remove, :topbar},
      {:gen, :gitignore},                    # generate project hygiene
      {:add, :credo},                        # install + configure packages
      {:add, :oban, if: :oban},              # optional, behind --oban
      {:install, :ash},                      # any package's own installer
      MyApp.Steps.DeployConfig               # or your own step module
    ]
  end
end
```

…and it runs as a Mix task, with flags derived from your optional steps:

```console
$ mix starter.run --oban
```

## Getting started

Starter is built for **freshly generated Phoenix apps** (see
[Compatibility](#compatibility)).

### 1. Create an app and add the dependency

```bash
mix phx.new my_app
cd my_app
```

Add `starter` to your deps in `mix.exs`:

```elixir
def deps do
  [
    {:starter, "~> 0.1", only: :dev},
    # ...
  ]
end
```

```bash
mix deps.get
```

### 2. Generate your workflow

```bash
mix starter.new
```

This creates **`lib/mix/tasks/my_app.workflow.ex`** — your workflow. It lists
every built-in step in a sensible order, each with a one-line description of
what it does. Open it and make it yours:

- **Delete** any step you don't want — the file is yours.
- **Reorder** steps freely; they run top to bottom.
- **Tag** a step with `if: :flag` to make it optional — it then only runs
  when you pass the matching `--flag`.

### 3. Run it

```bash
mix starter.run
```

Nothing is applied blindly: every change is shown as a diff, and you confirm
before anything touches disk. (`mix starter.run` finds and runs your workflow
task — invoking it directly as `mix my_app.workflow` does the same thing.)
When it finishes, set up the database and go:

```bash
mix ecto.setup
mix phx.server
```

> **Note:** the generated workflow enables the `vector` Postgres extension via
> the `pg_extensions` and `pgvector` steps. If your local Postgres doesn't
> have [pgvector](https://github.com/pgvector/pgvector) installed, either
> install it or delete those two steps from your workflow.

Keep the workflow file in your repo: it documents exactly how your app was set
up, and it's the file you'll copy into your next project.

### Running single steps

Every step also works on its own, no workflow required:

```bash
mix starter.add oban,credo      # install + configure packages
mix starter.remove daisy_ui     # undo a phx.new default
mix starter.gen gitignore       # generate config/code
mix starter.add --list          # see what's available (also: remove, gen)
```

### Scripts and CI

All commands are interactive by default (diff, then confirm). In a script or
CI, pass Igniter's standard `--yes` flag to auto-accept:

```bash
mix starter.new --yes && mix starter.run --yes
```

## Why not just…

- **`mix igniter.new --install a,b,c`?** Great for installing packages that
  ship installers. Starter is for everything around that: *removing*
  `phx.new` defaults (nothing else does this), installing packages that
  don't ship installers, ordering steps, optional flags, and keeping the
  whole ritual versioned in your repo.
- **A boilerplate/template repo?** Templates fork away from `phx.new` and
  rot. A workflow replays your preferences on top of whatever `phx.new`
  currently generates.

## Built-in steps

Starter deliberately ships **no step for packages that provide their own
Igniter installer** — `oban`, `oban_web`, `tidewave`, `ash`, and friends are
used via `{:install, :package}`, which runs the package's own installer so
upstream stays the authority. Built-in `add` steps exist only where upstream
ships no installer, and each does the minimum wiring a missing installer
would do. If a package later ships an installer, its step here retires.

| Kind | Step | What it does |
|---|---|---|
| add | `bun` | Replaces esbuild/tailwind with Bun: dep, package.json, config, watchers, aliases, tsconfig |
| add | `credo` | Dev/test dependency for static analysis |
| add | `dotenv_parser` | Loads `.env` in runtime config; creates and gitignores `.env` |
| add | `exsync` | Auto-recompilation on file changes (dev) |
| add | `libcluster` | Node clustering: dep, supervision child, Gossip topology in dev |
| add | `mix_test_watch` | Runs tests on file changes |
| add | `oban_pro` | Oban Pro: Smart engine, dynamic plugins, migration (requires license and an existing `oban` dep) |
| add | `pgvector` | Vector search: dep, Postgrex types, config, extension migration (merges into existing extensions migration) |
| add | `quokka` | Credo-configured formatter plugin |
| add | `remixicons` | Remix Icons as a Tailwind plugin with `remix-*` classes and a CoreComponents `icon` clause |
| add | `uuidv7` | Time-sortable UUID primary keys; updates your `Schema` module when present |
| remove | `agents_md` | Removes the generated `AGENTS.md` |
| remove | `daisy_ui` | Removes the `:daisyui` Mix dependency and CSS plugin blocks |
| remove | `live_title_suffix` | Removes the `" · Phoenix Framework"` title suffix |
| remove | `theme_toggle` | Removes the theme scripts, component, and usage |
| remove | `topbar` | Removes the topbar progress indicator |
| gen | `base_schema` | `MyApp.Schema` module with sensible key/timestamp defaults |
| gen | `ecto_force_drop` | `ecto.drop --force-drop` in the mix alias |
| gen | `generator_defaults` | Generators default to `binary_id` + `utc_datetime_usec` |
| gen | `gigalixir` | Gigalixir deploy: buildpacks, Procfile, release migration scripts, SSL config |
| gen | `gigalixir_libcluster` | Kubernetes clustering strategy for Gigalixir |
| gen | `gitignore` | Adds macOS system files to `.gitignore` |
| gen | `minimal_app_layout` | Replaces `Layouts.app/1` with a minimal header/main layout |
| gen | `minimal_home_page` | Replaces the `phx.new` marketing page with a minimal home page |
| gen | `mix_env_config` | `config :app, env: Mix.env()` for runtime environment checks |
| gen | `pg_extensions` | Migration enabling citext, pg_trgm, unaccent, and vector |
| gen | `sort_deps` | Sorts `mix.exs` dependencies alphabetically |
| gen | `tailwind_formatter` | HEEx formatter that sorts Tailwind classes |

Steps that pattern-match against `phx.new` output warn loudly when they find
nothing to change, instead of silently no-oping.

## Writing your own steps

A step is any module that implements `Igniter.Mix.Task`:

```elixir
defmodule MyApp.Steps.DeployConfig do
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Igniter.create_new_file(igniter, "config/deploy.exs", "# ...")
  end
end
```

Reference it directly in your workflow's step list. `Starter.Helpers` and
`Starter.Versions` provide conveniences for common patterns (app/repo module
names, checked file edits, migration timestamps, latest-version lookups).

## Sharing workflows

Workflows are modules, so they compose and travel. Keep your personal or
team ritual in a small "step pack" — a dev-dep containing custom steps and a
shared workflow module — and generate each new app's workflow from it:

```bash
mix starter.new --from MyTeam.Workflow
```

The generated file *expands* the shared workflow's steps, so the app owns
and documents its setup while your pack stays the template. Shared
workflows can also be included directly:

```elixir
def steps do
  [
    {:workflow, MyTeam.Baseline},
    {:add, :pgvector}
  ]
end
```

Steps that patch the output of `{:install, ...}` steps (which apply after
the in-run steps) should be Mix tasks queued after them:

```elixir
{:install, :oban},
{:queue, "my_team.oban_tweaks"}
```

## Compatibility

Starter supports **only the latest stable Phoenix** (currently 1.8) and its
`phx.new` output. Workflows warn when run against an app on an older Phoenix.
CI runs the generated workflow against a freshly generated `phx.new` app on
every commit, so generator drift breaks loudly here instead of silently in
your project.

## Roadmap

- A community workflow registry

Contributions welcome — a step is a small, self-contained module with tests,
and adding one is a great first PR.

## License

MIT — see [LICENSE.md](LICENSE.md).
