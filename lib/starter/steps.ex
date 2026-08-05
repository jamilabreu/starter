defmodule Starter.Steps do
  @moduledoc """
  Registry of Starter's built-in steps.

  Steps are discovered by module naming convention:

    * `:add` steps live under `Mix.Tasks.Starter.Add.*`
    * `:remove` steps live under `Mix.Tasks.Starter.Remove.*`
    * `:gen` steps live under `Mix.Tasks.Starter.Gen.*`

  A step's short name is the underscored form of its last module segment,
  so `Mix.Tasks.Starter.Add.Oban` resolves from `{:add, :oban}`.
  """

  @parents %{
    add: Mix.Tasks.Starter.Add,
    remove: Mix.Tasks.Starter.Remove,
    gen: Mix.Tasks.Starter.Gen
  }

  @kinds Map.keys(@parents)

  @doc "The step kinds Starter knows about."
  def kinds, do: @kinds

  @doc "Returns all step modules of the given kind."
  def modules(kind) when kind in @kinds do
    parent_parts = Module.split(@parents[kind])

    app_modules()
    |> Enum.filter(fn module ->
      parts = Module.split(module)
      List.starts_with?(parts, parent_parts) and length(parts) == length(parent_parts) + 1
    end)
    |> Enum.sort()
  end

  @doc "Returns the short names of all steps of the given kind."
  def names(kind), do: kind |> modules() |> Enum.map(&name/1)

  @doc "Returns the short name of a step module (e.g. `\"oban\"`)."
  def name(module) do
    module |> Module.split() |> List.last() |> Macro.underscore()
  end

  @doc """
  Resolves a short name to a step module.

  Matching is forgiving about case, underscores, and dashes, so `:daisy_ui`,
  `"daisyui"`, and `"daisy-ui"` all resolve to the same step.
  """
  def resolve(kind, name) when kind in @kinds do
    normalized = name |> to_string() |> String.downcase() |> String.replace(["_", "-"], "")

    kind
    |> modules()
    |> Enum.find(fn module ->
      String.replace(name(module), "_", "") == normalized
    end)
    |> case do
      nil -> :error
      module -> {:ok, module}
    end
  end

  defp app_modules do
    Application.ensure_loaded(:starter)

    case :application.get_key(:starter, :modules) do
      {:ok, modules} -> modules
      _ -> []
    end
  end
end
