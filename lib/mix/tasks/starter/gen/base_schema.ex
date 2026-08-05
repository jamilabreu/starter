defmodule Mix.Tasks.Starter.Gen.BaseSchema do
  @shortdoc "Generates a schema helper module"
  @moduledoc """
  Generates a `MyApp.Schema` module with sensible primary key and timestamp
  defaults. Uses `UUIDv7` for primary keys when the `uuidv7` dependency is
  present, `:binary_id` otherwise.
  """
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)

    id_type =
      if Igniter.Project.Deps.has_dep?(igniter, :uuidv7) do
        "UUIDv7"
      else
        ":binary_id"
      end

    content = """
    defmodule #{app_module}.Schema do
      defmacro __using__(_) do
        quote do
          use Ecto.Schema

          import Ecto.Changeset

          @primary_key {:id, #{id_type}, autogenerate: true}
          @foreign_key_type #{id_type}
          @timestamps_opts [type: :utc_datetime_usec]
        end
      end
    end
    """

    Igniter.create_new_file(igniter, "lib/#{app_name}/schema.ex", content)
  end
end
