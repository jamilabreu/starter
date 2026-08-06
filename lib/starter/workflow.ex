defmodule Starter.Workflow do
  @moduledoc """
  Defines a setup workflow: an ordered list of steps applied to a project.

  `use Starter.Workflow` turns a module into a full `Igniter.Mix.Task`. Name it
  under `Mix.Tasks` (for example `Mix.Tasks.MyApp.Workflow`) and it becomes
  runnable as `mix my_app.workflow` — or via `mix starter.run`, which finds it —
  with a `--flag` option for every optional step.

  ## Step forms

    * `{:add, :credo}` — get a package into the app: Starter's own step when
      it has one, otherwise the package is installed and its own installer
      runs. Which of the two applies is upstream's business, not something a
      workflow file should encode.
    * `{:remove, :topbar}` — run the built-in remove step `topbar`
    * `{:gen, :gitignore}` — run the built-in gen step `gitignore`
    * `{:add, :oban, if: :oban}` — only when the `--oban` flag is passed
    * `{:install, :ash}` — force the package's own installer, skipping any
      built-in step of the same name. Rarely needed; `{:add, :ash}` already
      resolves this way when Starter ships no step.
    * `{:task, "some.igniter.task"}` — compose any Igniter-aware Mix task,
      with optional argv and an `if:` option as a fourth element; non-Igniter
      tasks are skipped with a warning
    * `{:queue, "starter.add", ["oban_pro"]}` — queue any Mix task to run
      after the workflow's changes apply; use this only for work that must
      see the applied project on disk
    * `{:workflow, OtherWorkflow}` — include another workflow's steps
    * `MyApp.Steps.Custom` — any module implementing `Igniter.Mix.Task`,
      optionally as `{MyApp.Steps.Custom, if: :flag}`

  Queued tasks run non-interactively with `--yes` appended — their
  subprocesses have no stdin, so a prompt there could never be answered.
  Confirming the workflow's diff is the approval for everything it queues;
  queued tasks must tolerate the `--yes` flag (every Igniter task does).

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

  ## Example

      defmodule Mix.Tasks.MyApp.Workflow do
        use Starter.Workflow

        @impl Starter.Workflow
        def steps do
          [
            {:remove, :daisy_ui},
            {:gen, :gitignore},
            {:add, :credo},
            {:add, :oban, if: :oban}
          ]
        end
      end

  Running `mix my_app.workflow` applies every unconditional step;
  `mix my_app.workflow --oban` also applies the Oban step.
  """

  @typedoc "A single entry in a workflow's `c:steps/0` list."
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
          | {:workflow, module()}
          | {:workflow, module(), keyword()}
          | module()
          | {module(), keyword()}

  @doc "Returns the workflow's steps, in the order they should run."
  @callback steps() :: [step()]

  defmacro __using__(_opts) do
    quote do
      use Igniter.Mix.Task

      @behaviour Starter.Workflow

      @doc false
      def __starter_workflow__?, do: true

      @impl Igniter.Mix.Task
      def info(_argv, _composing_task) do
        schema = Enum.map(Starter.Workflow.flags(steps()), &{&1, :boolean})
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
  including flags of nested workflows.
  """
  @spec flags([step()]) :: [atom()]
  def flags(steps) when is_list(steps) do
    steps
    |> Enum.flat_map(fn
      {:workflow, module} -> flags_of(module)
      {:workflow, module, opts} -> List.wrap(opts[:if]) ++ flags_of(module)
      {:task, _task, _argv, opts} when is_list(opts) -> List.wrap(opts[:if])
      {:queue, _task, _argv, opts} when is_list(opts) -> List.wrap(opts[:if])
      {_kind, _name, opts} when is_list(opts) -> List.wrap(opts[:if])
      {module, opts} when is_atom(module) and is_list(opts) -> List.wrap(opts[:if])
      _step -> []
    end)
    |> Enum.uniq()
  end

  @doc "Returns every flag used by the given workflow module."
  @spec flags_of(module()) :: [atom()]
  def flags_of(workflow) when is_atom(workflow), do: flags(workflow.steps())
end
