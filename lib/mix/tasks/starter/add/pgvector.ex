defmodule Mix.Tasks.Starter.Add.Pgvector do
  @shortdoc "Adds pgvector support"
  @moduledoc "Adds `pgvector` support for vector similarity search in Postgres."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> add_postgrex_types()
    |> edit_config()
    |> add_migration()
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, Starter.Versions.latest_hex_dep(:pgvector))
  end

  # Reuses an existing add_extensions migration when one is present so the
  # vector extension lands alongside the others.
  defp add_migration(igniter) do
    repo = Helpers.repo(igniter)
    repo_name = repo |> Module.split() |> List.last() |> Macro.underscore()
    migrations_path = "priv/#{repo_name}/migrations"

    igniter = Igniter.include_glob(igniter, Path.join(migrations_path, "*_add_extensions.exs"))

    migration_path =
      igniter.rewrite
      |> Rewrite.sources()
      |> Enum.map(& &1.path)
      |> Enum.find(
        &String.match?(&1, ~r/priv\/#{repo_name}\/migrations\/\d+_add_extensions\.exs/)
      )

    if migration_path do
      update_extensions_migration(igniter, migration_path)
    else
      body = """
      def up do
        execute "CREATE EXTENSION IF NOT EXISTS vector"
      end

      def down do
        execute "DROP EXTENSION IF EXISTS vector"
      end
      """

      Helpers.gen_migration(igniter, repo, "add_extensions", body: body)
    end
  end

  defp update_extensions_migration(igniter, migration_path) do
    source = Rewrite.source!(igniter.rewrite, migration_path)
    content = Rewrite.Source.get(source, :content)

    if String.contains?(content, ~s|CREATE EXTENSION IF NOT EXISTS vector|) do
      igniter
    else
      Igniter.update_elixir_file(igniter, migration_path, fn zipper ->
        zipper
        |> Igniter.Code.Function.move_to_def(:up, 0)
        |> case do
          {:ok, zipper} ->
            Igniter.Code.Common.add_code(
              zipper,
              ~s|execute "CREATE EXTENSION IF NOT EXISTS vector"|
            )

          :error ->
            zipper
        end
        |> Igniter.Code.Function.move_to_def(:down, 0)
        |> case do
          {:ok, zipper} ->
            Igniter.Code.Common.add_code(
              zipper,
              ~s|execute "DROP EXTENSION IF EXISTS vector"|
            )

          :error ->
            zipper
        end
      end)
    end
  end

  defp add_postgrex_types(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)
    types_module = Module.concat([app_module, "PostgrexTypes"])

    content = """
    Postgrex.Types.define(
      #{inspect(types_module)},
      Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
      []
    )
    """

    Igniter.create_new_file(igniter, "lib/#{app_name}/postgrex_types.ex", content)
  end

  defp edit_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_module = Helpers.app_module(igniter)
    repo = Helpers.repo(igniter)
    types_module = Module.concat([app_module, "PostgrexTypes"])

    Igniter.Project.Config.configure(
      igniter,
      "config.exs",
      app_name,
      [repo, :types],
      types_module
    )
  end
end
