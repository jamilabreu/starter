defmodule Mix.Tasks.Starter.Add.Credo do
  @shortdoc "Adds Credo for static code analysis"
  @moduledoc "Adds `credo` as a dev/test dependency."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Starter.Versions.latest_hex_dep(:credo)

    Igniter.Project.Deps.add_dep(igniter, {package, version, only: [:dev, :test], runtime: false})
  end
end
