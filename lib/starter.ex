defmodule Starter do
  @moduledoc """
  Composable project starters for Phoenix applications.

  Starter turns your post-`phx.new` ritual into a *starter*: an ordered,
  flag-aware list of steps that lives in your project, built on
  [Igniter](https://hexdocs.pm/igniter).

  ## Concepts

    * **Step** — a single unit of setup work. Every step is an
      `Igniter.Mix.Task`, so steps compose, preview their changes as diffs,
      and never blindly overwrite files. Starter ships a library of built-in
      steps in three kinds: `:add` (install and wire up a package), `:remove`
      (undo a `phx.new` default), and `:gen` (generate configuration or code).

    * **Starter** — a module that lists steps in order. Starters support
      optional steps behind flags, arbitrary Mix task composition, your own
      custom step modules, and even other starters.

  ## Quick start

  Generate your starter, then run it:

      mix starter.new
      mix starter.run

  The generated starter documents every step in place — delete what you
  don't want, reorder freely, and tag steps with `if: :flag` to make them
  optional (`mix starter.run --oban-pro`).

  ## Writing a starter

  `use Starter` turns a module into a full `Igniter.Mix.Task`. Name it
  under `Mix.Tasks` (for example `Mix.Tasks.MyApp.Starter`) and it becomes
  runnable as `mix my_app.starter` — or via `mix starter.run`, which finds
  it — with a `--flag` option for every optional step.

      defmodule Mix.Tasks.MyApp.Starter do
        use Starter

        @impl Starter
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

  Running `mix my_app.starter` applies every unconditional step;
  `mix my_app.starter --oban` also applies the Oban step.

  ## Step forms

    * `{:add, :credo}` — get a package into the app: Starter's own step when
      it has one, otherwise the package is installed and its own installer
      runs. Which of the two applies is upstream's business, not something a
      starter file should encode.
    * `{:remove, :topbar}` — run the built-in remove step `topbar`
    * `{:gen, :gitignore}` — run the built-in gen step `gitignore`
    * `{:add, :oban, if: :oban}` — only when the `--oban` flag is passed
    * `{:install, :ash}` — force the package's own installer, skipping any
      built-in step of the same name. Rarely needed; `{:add, :ash}` already
      resolves this way when Starter ships no step.
    * `{:add, :"oban.oban_pro"}` — a package from a private Hex repo or
      organization. Names resolve against public Hex unless qualified, so
      `repo.package` (and `org/package`) must be spelled out.
    * `{:task, "some.igniter.task"}` — compose any Igniter-aware Mix task,
      with optional argv and an `if:` option as a fourth element; non-Igniter
      tasks are skipped with a warning
    * `{:queue, "starter.add", ["oban_pro"]}` — queue any Mix task to run
      after the starter's changes apply; use this only for work that must
      see the applied project on disk
    * `{:starter, OtherStarter}` — include another starter's steps
    * `MyApp.Steps.Custom` — any module implementing `Igniter.Mix.Task`,
      optionally as `{MyApp.Steps.Custom, if: :flag}`

  Queued tasks run non-interactively with `--yes` appended — their
  subprocesses have no stdin, so a prompt there could never be answered.
  Confirming the starter's diff is the approval for everything it queues;
  queued tasks must tolerate the `--yes` flag (every Igniter task does).

  ## Composition

  Starters compose as a tree, not just a flat list. A `{:starter, Other}`
  step includes another starter's steps, an included starter can include
  starters itself — to any depth — and an include can be flag-gated:
  `{:starter, Other, if: :flag}`. Packages and custom steps are the leaves.

  At run time the tree is flattened depth-first into one ordered step list,
  so a nested starter's steps run exactly where its include appears.
  Packages the whole tree installs are deduped and fetched up front, a
  single diff covers the entire run, and flags declared anywhere in the
  tree surface as `--flag` options on the task you invoke.

  ## Ordering

  Steps apply in list order, installers included, and every change lands in
  one diff you confirm once. A step placed after one that installs a package
  sees its effects, so ordering is just list position — e.g.
  `{:gen, :sort_deps}` at the end sorts the deps the installers added.

  The one exception is dependencies. Packages that resolve to an install are
  added to `mix.exs` and fetched *before* any step runs, because their
  installers have to be on disk to compose. That dependency change is
  written and confirmed on its own, ahead of the run's main diff.

  Queued steps still run last, in list order, after everything applies.

  Each run prints a plan showing what every step resolved to — a built-in
  step, a package's installer, a plain dependency, or queued work.
  """

  @typedoc "A single entry in a starter's `c:steps/0` list."
  @type step ::
          {:add | :remove | :gen, atom()}
          | {:add | :remove | :gen, atom(), keyword()}
          | {:install, atom()}
          | {:install, atom(), keyword()}
          | {:queue, String.t()}
          | {:queue, String.t(), [String.t()]}
          | {:queue, String.t(), [String.t()], keyword()}
          | {:task, String.t()}
          | {:task, String.t(), [String.t()]}
          | {:task, String.t(), [String.t()], keyword()}
          | {:starter, module()}
          | {:starter, module(), keyword()}
          | module()
          | {module(), keyword()}

  @doc "Returns the starter's steps, in the order they should run."
  @callback steps() :: [step()]

  defmacro __using__(_opts) do
    quote do
      use Igniter.Mix.Task

      @behaviour Starter

      @doc false
      def __starter__?, do: true

      @impl Igniter.Mix.Task
      def info(_argv, _composing_task) do
        schema = Enum.map(Starter.flags(steps()), &{&1, :boolean})
        %Igniter.Mix.Task.Info{schema: schema}
      end

      @impl Igniter.Mix.Task
      def igniter(igniter) do
        Starter.Runner.run(igniter, __MODULE__, igniter.args.options)
      end

      defoverridable info: 2, igniter: 1
    end
  end

  @doc """
  Returns every flag referenced by `if:` options in the given steps,
  including flags of nested starters.
  """
  @spec flags([step()]) :: [atom()]
  def flags(steps) when is_list(steps) do
    steps
    |> Enum.flat_map(fn
      {:starter, module} -> flags_of(module)
      {:starter, module, opts} -> List.wrap(opts[:if]) ++ flags_of(module)
      {:task, _task, _argv, opts} when is_list(opts) -> List.wrap(opts[:if])
      {:queue, _task, _argv, opts} when is_list(opts) -> List.wrap(opts[:if])
      {_kind, _name, opts} when is_list(opts) -> List.wrap(opts[:if])
      {module, opts} when is_atom(module) and is_list(opts) -> List.wrap(opts[:if])
      _step -> []
    end)
    |> Enum.uniq()
  end

  @doc "Returns every flag used by the given starter module."
  @spec flags_of(module()) :: [atom()]
  def flags_of(starter) when is_atom(starter), do: flags(starter.steps())
end
