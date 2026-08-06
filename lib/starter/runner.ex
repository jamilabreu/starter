defmodule Starter.Runner do
  @moduledoc """
  Expands and runs a starter's steps against an igniter.

  You rarely call this directly — `use Starter` wires it up for you.
  """

  # Starter supports only the latest stable Phoenix. The check version is a
  # sentinel meaning "any release in the supported series": an app requirement
  # like "~> 1.8.8" admits 1.8.99, while "~> 1.7.0" does not.
  @supported_phoenix_series "1.8"
  @phoenix_check_version "1.8.99"

  # Igniter runs queued tasks via Mix.shell().cmd, which has no stdin — a
  # prompting subprocess would stall forever waiting for input that can
  # never arrive, so queued tasks always run with --yes (confirming the
  # starter is the approval for what it queues). Nothing else is forwarded:
  # the starter's custom flags have already done their job selecting steps,
  # and leaking them crashes queued tasks with strict option parsers.
  # Installs no longer go through here — see prepare_installs/2.
  @queued_flags ["--yes"]

  @doc """
  Runs every step of `starter` in order, skipping optional steps whose
  flag is absent from `opts`.

  Warns when the target app's Phoenix requirement is older than the
  supported series (#{@supported_phoenix_series}).
  """
  @spec run(Igniter.t(), module(), keyword()) :: Igniter.t()
  def run(igniter, starter, opts \\ []) when is_atom(starter) do
    steps = expand_all(starter, opts)

    igniter
    |> check_phoenix_version()
    |> prepare_installs(steps)
    |> show_plan(steps)
    |> then(&Enum.reduce(steps, &1, fn step, igniter -> apply_step(igniter, step) end))
  end

  # Printed after the dependency fetch, because which packages ship an
  # installer is only knowable once they are on disk. This is where a reader
  # sees what each step resolved to and what defers — the step list itself no
  # longer distinguishes them.
  defp show_plan(igniter, steps) do
    if igniter.assigns[:test_mode?] do
      igniter
    else
      Mix.shell().info(["\n", IO.ANSI.bright(), "Starter plan", IO.ANSI.reset()])
      Enum.each(steps, &Mix.shell().info("  #{describe(&1)}"))
      Mix.shell().info("")
      igniter
    end
  end

  defp describe({:module, module}), do: label(module)
  defp describe({:task, task, _argv}), do: task

  defp describe({:install, package}) do
    case Mix.Task.get("#{package}.install") do
      nil -> "#{package} — dependency only, ships no installer"
      _ -> "#{package} — #{package}.install"
    end
  end

  defp describe({:queue, task, _argv}), do: "#{task} — queued, runs after this run applies"

  defp label(module) do
    case Module.split(module) do
      ["Mix", "Tasks" | _] -> Mix.Task.task_name(module)
      _ -> inspect(module)
    end
  end

  @doc """
  Returns the packages a run of `starter` would install, in step order,
  with optional steps resolved against `opts`.

  These are added to `mix.exs` and fetched before any step runs, so this is
  the set whose dependency changes reach disk ahead of the run's diff.
  """
  @spec installs(module(), keyword()) :: [atom()]
  def installs(starter, opts \\ []) when is_atom(starter) do
    for {:install, package} <- expand_all(starter, opts), do: package
  end

  # Flattens nested starters and drops skipped steps, so the whole run is a
  # single ordered list. Installs need to be known up front (see
  # prepare_installs/2), which means resolving nesting before applying
  # anything.
  defp expand_all(starter, opts) do
    starter.steps()
    |> Enum.map(&expand(&1, opts))
    |> Enum.flat_map(fn
      :skip -> []
      {:starter, module} -> expand_all(module, opts)
      step -> [step]
    end)
  end

  # Adds every {:install, ...} package to mix.exs and fetches once, before any
  # step runs. Igniter writes only the deps change to disk here, leaving the
  # rest of the run's diff pending — which is what lets the installers compose
  # into this run instead of being queued into a subprocess.
  defp prepare_installs(igniter, steps) do
    case for {:install, package} <- steps, do: package, uniq: true do
      [] ->
        igniter

      packages ->
        # Resolving versions queries Hex and apply_and_fetch_dependencies/2
        # raises in test mode, so installs are inert under Igniter.Test: no
        # installer resolves and each step no-ops.
        if igniter.assigns[:test_mode?] do
          igniter
        else
          packages
          |> Enum.reduce(igniter, &add_install_dep(&2, &1))
          |> Igniter.apply_and_fetch_dependencies(
            operation: "compiling #{Enum.join(packages, ", ")}",
            yes: "--yes" in argv(igniter),
            yes_to_deps: "--yes-to-deps" in argv(igniter)
          )
        end
    end
  end

  defp add_install_dep(igniter, package) do
    dep =
      package
      |> to_string()
      |> Igniter.Project.Deps.determine_dep_type_and_version!(argv: argv(igniter))

    Igniter.Project.Deps.add_dep(igniter, dep)
  end

  defp argv(igniter) do
    case igniter.args do
      %{argv: argv} when is_list(argv) -> argv
      _ -> []
    end
  end

  defp check_phoenix_version(igniter) do
    if igniter.assigns[:starter_phoenix_checked] do
      igniter
    else
      igniter = Igniter.assign(igniter, :starter_phoenix_checked, true)

      with {:ok, declaration} when is_binary(declaration) <-
             Igniter.Project.Deps.get_dep(igniter, :phoenix),
           {:ok, requirement} when is_binary(requirement) <- extract_requirement(declaration),
           {:ok, _} <- Version.parse_requirement(requirement),
           false <- Version.match?(@phoenix_check_version, requirement) do
        Igniter.add_warning(igniter, """
        This app depends on phoenix #{inspect(requirement)}, but Starter supports only \
        the latest stable Phoenix (#{@supported_phoenix_series}). Steps may not apply cleanly.
        """)
      else
        _ -> igniter
      end
    end
  end

  defp extract_requirement(declaration) do
    case Code.string_to_quoted(declaration) do
      {:ok, {_name, requirement}} -> {:ok, requirement}
      {:ok, {:{}, _, [_name, requirement | _]}} -> {:ok, requirement}
      _ -> :error
    end
  end

  defp apply_step(igniter, {:module, module}), do: Igniter.compose_task(igniter, module)

  defp apply_step(igniter, {:task, task, argv}) do
    Igniter.compose_task(igniter, task, argv, fn igniter ->
      Igniter.add_warning(igniter, """
      Step {:task, #{inspect(task)}} was skipped: `mix #{task}` is not an \
      Igniter task, so it cannot be composed into a starter. Run it \
      directly instead: mix #{task} #{Enum.join(argv, " ")}
      """)
    end)
  end

  # The dep is already added and fetched by prepare_installs/2, so all that is
  # left is the package's own installer, if it ships one. Composing it here
  # puts its changes in this run's diff, at this position in the step list.
  defp apply_step(igniter, {:install, package}) do
    case Mix.Task.get("#{package}.install") do
      nil -> igniter
      task -> Igniter.compose_task(igniter, task, [])
    end
  end

  defp apply_step(igniter, {:queue, task, argv}) do
    Igniter.add_task(igniter, task, argv ++ @queued_flags)
  end

  defp expand({:add, name}, _opts) when is_atom(name), do: add(name)

  defp expand({:add, name, step_opts}, opts) when is_atom(name) do
    if included?(step_opts, opts), do: add(name), else: :skip
  end

  defp expand({kind, name}, _opts) when kind in [:remove, :gen] and is_atom(name) do
    resolve!(kind, name)
  end

  defp expand({kind, name, step_opts}, opts) when kind in [:remove, :gen] do
    if included?(step_opts, opts), do: resolve!(kind, name), else: :skip
  end

  defp expand({:install, package}, _opts) when is_atom(package), do: {:install, package}

  defp expand({:install, package, step_opts}, opts) when is_atom(package) do
    if included?(step_opts, opts), do: {:install, package}, else: :skip
  end

  defp expand({:queue, task}, _opts) when is_binary(task), do: {:queue, task, []}

  defp expand({:queue, task, argv}, _opts) when is_binary(task) and is_list(argv) do
    {:queue, task, argv}
  end

  defp expand({:queue, task, argv, step_opts}, opts) when is_binary(task) do
    if included?(step_opts, opts), do: {:queue, task, argv}, else: :skip
  end

  defp expand({:starter, module}, _opts) when is_atom(module), do: {:starter, module}

  defp expand({:starter, module, step_opts}, opts) when is_atom(module) do
    if included?(step_opts, opts), do: {:starter, module}, else: :skip
  end

  defp expand({:task, task}, _opts) when is_binary(task), do: {:task, task, []}

  defp expand({:task, task, argv}, _opts) when is_binary(task) and is_list(argv) do
    {:task, task, argv}
  end

  defp expand({:task, task, argv, step_opts}, opts) when is_binary(task) do
    if included?(step_opts, opts), do: {:task, task, argv}, else: :skip
  end

  defp expand({module, step_opts}, opts) when is_atom(module) and is_list(step_opts) do
    if included?(step_opts, opts), do: {:module, module}, else: :skip
  end

  defp expand(module, _opts) when is_atom(module), do: {:module, module}

  defp expand(step, _opts) do
    Mix.raise("Invalid starter step: #{inspect(step)}")
  end

  defp included?(step_opts, opts) do
    case step_opts[:if] do
      nil -> true
      flag -> Keyword.get(opts, flag, false)
    end
  end

  # `{:add, name}` means "get this package into my app, correctly". Starter's
  # own step wins when it has one; otherwise the package is installed and its
  # own installer runs. Which path a package takes is upstream's business and
  # changes over time, so it is not something a starter file should encode —
  # when a package gains an installer, its Starter step retires and starters
  # naming it keep working unchanged.
  defp add(name) do
    case Starter.Steps.resolve(:add, name) do
      {:ok, module} ->
        {:module, module}

      # Falling through to an install means a typo'd step name would become a
      # doomed Hex lookup, so names that closely resemble a built-in step are
      # treated as mistakes rather than package names.
      :error ->
        case Enum.filter(Starter.Steps.names(:add), &similar?(&1, to_string(name))) do
          [] ->
            {:install, name}

          suggestions ->
            Mix.raise("""
            Unknown add step: #{inspect(name)}

            Did you mean: #{Enum.join(suggestions, ", ")}?

            Names that are not built-in steps are installed as packages, but \
            #{inspect(name)} looks like a typo rather than a package name.
            """)
        end
    end
  end

  defp similar?(step, name), do: String.jaro_distance(step, name) > 0.85

  defp resolve!(kind, name) do
    case Starter.Steps.resolve(kind, name) do
      {:ok, module} ->
        {:module, module}

      :error ->
        Mix.raise("""
        Unknown #{kind} step: #{inspect(name)}

        Available #{kind} steps: #{Enum.join(Starter.Steps.names(kind), ", ")}
        """)
    end
  end
end
