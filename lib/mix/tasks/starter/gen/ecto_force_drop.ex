defmodule Mix.Tasks.Starter.Gen.EctoForceDrop do
  @shortdoc "Updates the ecto.drop alias to use --force-drop"
  @moduledoc "Updates the `ecto.drop` alias in `mix.exs` to use `--force-drop`."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Helpers.update_file_content(igniter, "mix.exs", fn content ->
      String.replace(content, "\"ecto.drop\"", "\"ecto.drop --force-drop\"")
    end)
  end
end
