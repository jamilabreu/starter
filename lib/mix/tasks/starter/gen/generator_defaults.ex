defmodule Mix.Tasks.Starter.Gen.GeneratorDefaults do
  @shortdoc "Configures generators and migration timestamps"
  @moduledoc "Configures generators for `binary_id` and `utc_datetime_usec` timestamps."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    repo = Helpers.repo(igniter)

    igniter
    |> Igniter.Project.Config.configure("config.exs", app_name, [:generators],
      timestamp_type: :utc_datetime_usec,
      binary_id: true
    )
    |> Igniter.Project.Config.configure("config.exs", app_name, [repo],
      migration_timestamps: [type: :utc_datetime_usec]
    )
  end
end
