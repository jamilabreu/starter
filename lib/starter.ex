defmodule Starter do
  @moduledoc """
  Composable setup workflows for Phoenix applications.

  Starter turns your post-`phx.new` ritual into a *workflow*: an ordered,
  flag-aware list of steps that lives in your project, built on
  [Igniter](https://hexdocs.pm/igniter).

  ## Concepts

    * **Step** — a single unit of setup work. Every step is an
      `Igniter.Mix.Task`, so steps compose, preview their changes as diffs,
      and never blindly overwrite files. Starter ships a library of built-in
      steps in three kinds: `:add` (install and wire up a package), `:remove`
      (undo a `phx.new` default), and `:gen` (generate configuration or code).

    * **Workflow** — a module that lists steps in order. Workflows support
      optional steps behind flags, arbitrary Mix task composition, your own
      custom step modules, and even other workflows.

  ## Quick start

  Generate your workflow, then run it:

      mix starter.new
      mix starter.run

  The generated workflow documents every step in place — delete what you
  don't want, reorder freely, and tag steps with `if: :flag` to make them
  optional (`mix starter.run --oban-pro`).

  ## Writing a workflow

      defmodule Mix.Tasks.MyApp.Workflow do
        use Starter.Workflow

        @impl Starter.Workflow
        def steps do
          [
            {:remove, :daisy_ui},
            {:remove, :topbar},
            {:gen, :gitignore},
            {:add, :credo},
            {:add, :oban, if: :oban},
            {:task, "igniter.install", ["ash"]}
          ]
        end
      end

  See `Starter.Workflow` for every supported step form.
  """
end
