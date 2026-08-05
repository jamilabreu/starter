defmodule Starter.Runner do
  @moduledoc """
  Expands and runs a workflow's steps against an igniter.

  You rarely call this directly — `use Starter.Workflow` wires it up for you.
  """

  # Starter supports only the latest stable Phoenix. The check version is a
  # sentinel meaning "any release in the supported series": an app requirement
  # like "~> 1.8.8" admits 1.8.99, while "~> 1.7.0" does not.
  @supported_phoenix_series "1.8"
  @phoenix_check_version "1.8.99"

  @doc """
  Runs every step of `workflow` in order, skipping optional steps whose
  flag is absent from `opts`.

  Warns when the target app's Phoenix requirement is older than the
  supported series (#{@supported_phoenix_series}).
  """
  @spec run(Igniter.t(), module(), keyword()) :: Igniter.t()
  def run(igniter, workflow, opts \\ []) when is_atom(workflow) do
    igniter = check_phoenix_version(igniter)
    Enum.reduce(workflow.steps(), igniter, &apply_step(&2, &1, opts))
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

  defp apply_step(igniter, step, opts) do
    case expand(step, opts) do
      :skip ->
        igniter

      {:module, module} ->
        Igniter.compose_task(igniter, module)

      {:task, task, argv} ->
        Igniter.compose_task(igniter, task, argv, fn igniter ->
          Igniter.add_warning(igniter, """
          Step {:task, #{inspect(task)}} was skipped: `mix #{task}` is not an \
          Igniter task, so it cannot be composed into a workflow. Run it \
          directly instead: mix #{task} #{Enum.join(argv, " ")}
          """)
        end)

      {:install, package} ->
        # igniter.install fetches the package and runs its own installer task
        # (e.g. oban.install) when it ships one, falling back to a plain dep
        # add. It cannot be composed mid-run, so it is queued to run right
        # after the workflow's changes apply.
        Igniter.add_task(igniter, "igniter.install", [to_string(package) | queued_flags(igniter)])

      {:queue, task, argv} ->
        # Queued tasks run in order after the workflow's changes apply —
        # the way to sequence work after {:install, ...} steps.
        Igniter.add_task(igniter, task, argv ++ queued_flags(igniter))

      {:workflow, module} ->
        run(igniter, module, opts)
    end
  end

  # Igniter runs queued tasks via Mix.shell().cmd, which has no stdin — a
  # prompting subprocess would stall forever waiting for input that can
  # never arrive. Queued tasks therefore always run with --yes; the user
  # already reviewed and confirmed the workflow that queued them.
  defp queued_flags(igniter) do
    Enum.uniq(argv_flags(igniter) ++ ["--yes"])
  end

  defp argv_flags(%{args: %{argv_flags: flags}}) when is_list(flags), do: flags
  defp argv_flags(_igniter), do: []

  defp expand({kind, name}, _opts) when kind in [:add, :remove, :gen] and is_atom(name) do
    resolve!(kind, name)
  end

  defp expand({kind, name, step_opts}, opts) when kind in [:add, :remove, :gen] do
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

  defp expand({:workflow, module}, _opts) when is_atom(module), do: {:workflow, module}

  defp expand({:workflow, module, step_opts}, opts) when is_atom(module) do
    if included?(step_opts, opts), do: {:workflow, module}, else: :skip
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
    Mix.raise("Invalid workflow step: #{inspect(step)}")
  end

  defp included?(step_opts, opts) do
    case step_opts[:if] do
      nil -> true
      flag -> Keyword.get(opts, flag, false)
    end
  end

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
