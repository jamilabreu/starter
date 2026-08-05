defmodule Mix.Tasks.Starter.Add.Uuidv7 do
  @shortdoc "Adds UUIDv7 support"
  @moduledoc "Adds `uuidv7` for time-sortable UUID primary keys. Updates the app's `Schema` module when present."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> update_schema()
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, Starter.Versions.latest_hex_dep(:uuidv7))
  end

  defp update_schema(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    schema_path = "lib/#{app_name}/schema.ex"

    if Igniter.exists?(igniter, schema_path) do
      Starter.Helpers.update_file_content(igniter, schema_path, fn content ->
        String.replace(content, ":binary_id", "UUIDv7")
      end)
    else
      igniter
    end
  end
end
