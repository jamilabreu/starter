defmodule Mix.Tasks.Starter.Gen.MixEnvConfig do
  @shortdoc "Adds environment config"
  @moduledoc "Adds `config :app, env: Mix.env()` to `config.exs` so the environment is readable at runtime."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [:env],
      {:code, quote(do: Mix.env())}
    )
  end
end
