defmodule Mix.Tasks.Starter.Add.Quokka do
  @shortdoc "Adds Quokka, a Credo-configured formatter plugin"
  @moduledoc "Adds `quokka`, a formatter plugin that rewrites code to match your Credo configuration."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Starter.Versions.latest_hex_dep(:quokka)

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> add_plugin()
  end

  # `mix format` aborts outright on a formatter plugin it cannot load, and
  # Igniter re-reads `.formatter.exs` as soon as it changes — so the dep has
  # to be fetched before the plugin is named, not after. Fetching here is what
  # lets this be wired up automatically instead of left as a notice.
  defp add_plugin(igniter) do
    if igniter.assigns[:test_mode?] do
      igniter
    else
      igniter
      |> Igniter.apply_and_fetch_dependencies(
        operation: "compiling quokka",
        yes: "--yes" in argv(igniter),
        yes_to_deps: "--yes-to-deps" in argv(igniter)
      )
      |> Igniter.Project.Formatter.add_formatter_plugin(Quokka)
    end
  end

  defp argv(igniter) do
    case igniter.args do
      %{argv: argv} when is_list(argv) -> argv
      _ -> []
    end
  end
end
