defmodule Starter.Workflow do
  @moduledoc """
  Defines a setup workflow: an ordered list of steps applied to a project.

  `use Starter.Workflow` turns a module into a full `Igniter.Mix.Task`. Name it
  under `Mix.Tasks` (for example `Mix.Tasks.MyApp.Workflow`) and it becomes
  runnable as `mix my_app.workflow` — or via `mix starter.run`, which finds it —
  with a `--flag` option for every optional step.

  ## Step forms

    * `{:add, :oban}` — run the built-in add step `oban`
    * `{:remove, :topbar}` — run the built-in remove step `topbar`
    * `{:gen, :gitignore}` — run the built-in gen step `gitignore`
    * `{:add, :oban, if: :oban}` — only when the `--oban` flag is passed
    * `{:install, :ash}` — fetch a package via `mix igniter.install` and run
      the package's own installer when it ships one. Queued to run right
      after the workflow's other changes apply.
    * `{:queue, "starter.add", ["oban_pro"]}` — queue any Mix task to run
      after the workflow's changes apply; queued tasks run in order, so this
      is how to sequence work after `{:install, ...}` steps
    * `{:task, "some.igniter.task"}` — compose any Igniter-aware Mix task,
      with optional argv and an `if:` option as a fourth element; non-Igniter
      tasks are skipped with a warning
    * `{:workflow, OtherWorkflow}` — include another workflow's steps
    * `MyApp.Steps.Custom` — any module implementing `Igniter.Mix.Task`,
      optionally as `{MyApp.Steps.Custom, if: :flag}`

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
