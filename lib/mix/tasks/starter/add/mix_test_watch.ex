defmodule Mix.Tasks.Starter.Add.MixTestWatch do
  @shortdoc "Adds mix_test_watch for running tests on file changes"
  @moduledoc "Adds `mix_test_watch` to automatically run tests on file changes."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {package, version} = Starter.Versions.latest_hex_dep(:mix_test_watch)

    igniter
    |> Igniter.Project.Deps.add_dep({package, version, only: [:dev, :test], runtime: false})
    |> Igniter.add_notice("Run `mix test.watch` to run tests on file changes")
  end
end
