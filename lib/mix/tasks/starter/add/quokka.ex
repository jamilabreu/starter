defmodule Mix.Tasks.Starter.Add.Quokka do
  @shortdoc "Adds Quokka, a Credo-configured formatter plugin"
  @moduledoc "Adds `quokka`, a formatter plugin that rewrites code to match your Credo configuration."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Starter.Versions.latest_hex_dep(:quokka)

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Add `Quokka` to the `plugins` list in `.formatter.exs`")
  end
end
