defmodule Starter.Steps.Dispatcher do
  @moduledoc false

  # Shared implementation for the starter.add / starter.remove / starter.gen
  # dispatcher tasks: comma-separated names in, composed steps out.

  def run(igniter, kind, nil) do
    Mix.shell().error("Usage: mix starter.#{kind} <names>\n")
    Mix.shell().info("Run `mix starter.#{kind} --list` to see available steps.")
    igniter
  end

  def run(igniter, kind, names) do
    names
    |> to_string()
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reduce(igniter, fn name, acc ->
      case Starter.Steps.resolve(kind, name) do
        {:ok, module} ->
          Igniter.compose_task(acc, module)

        :error ->
          Mix.shell().error("Unknown step: #{name}\n")
          list(kind)
          acc
      end
    end)
  end

  def list(kind) do
    case Starter.Steps.names(kind) do
      [] ->
        Mix.shell().info("No #{kind} steps available.")

      names ->
        Mix.shell().info("Available #{kind} steps:\n")
        Enum.each(names, &Mix.shell().info("  mix starter.#{kind} #{&1}"))
    end
  end
end
