defmodule Mix.Tasks.Starter.Add.SmokeTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "exsync adds a dev-only dep and dev config" do
    igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Add.Exsync)

    assert diff(igniter, only: "mix.exs") =~ ":exsync"
    assert diff(igniter, only: "config/dev.exs") =~ "src_monitor"
  end

  test "mix_test_watch adds a dev/test dep and a notice" do
    igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Add.MixTestWatch)

    assert diff(igniter, only: "mix.exs") =~ ":mix_test_watch"
    assert Enum.any?(igniter.notices, &(&1 =~ "test.watch"))
  end

  # The formatter plugin is wired up for real now rather than left to a
  # notice, but that needs the dep fetched first, which cannot happen under
  # Igniter.Test — so only the dep is observable here.
  test "quokka adds a dev/test dep" do
    igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Add.Quokka)

    assert diff(igniter, only: "mix.exs") =~ ":quokka"
    refute Enum.any?(igniter.notices, &(&1 =~ "Add `Quokka`"))
  end

  test "dotenv_parser adds dep, .env, runtime config, and gitignore entry" do
    igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Add.DotenvParser)

    assert diff(igniter, only: "mix.exs") =~ ":dotenv_parser"
    assert_creates(igniter, ".env", "VARIABLE=value")
    assert diff(igniter, only: "config/runtime.exs") =~ "DotenvParser.load_file"
    assert diff(igniter, only: ".gitignore") =~ ".env"
  end

  test "uuidv7 adds the dep and rewrites an existing schema module" do
    schema = """
    defmodule Test.Schema do
      defmacro __using__(_) do
        quote do
          @primary_key {:id, :binary_id, autogenerate: true}
          @foreign_key_type :binary_id
        end
      end
    end
    """

    igniter =
      test_project(files: %{"lib/test/schema.ex" => schema})
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.Uuidv7)

    assert diff(igniter, only: "mix.exs") =~ ":uuidv7"
    schema_diff = diff(igniter, only: "lib/test/schema.ex")
    assert schema_diff =~ "UUIDv7"
    refute schema_diff =~ "+ |          @primary_key {:id, :binary_id"
  end

  test "libcluster adds dep, supervision child, and dev topology" do
    igniter = Igniter.compose_task(phx_test_project(), Mix.Tasks.Starter.Add.Libcluster)

    assert diff(igniter, only: "mix.exs") =~ ":libcluster"
    assert diff(igniter, only: "lib/test/application.ex") =~ "Cluster.Supervisor"
    assert diff(igniter, only: "config/dev.exs") =~ "Cluster.Strategy.Gossip"
  end

  test "pgvector adds dep, postgrex types, config, and extension migration" do
    igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Add.Pgvector)

    assert diff(igniter, only: "mix.exs") =~ ":pgvector"
    assert diff(igniter, only: "lib/test/postgrex_types.ex") =~ "Postgrex.Types.define"
    assert diff(igniter, only: "config/config.exs") =~ "Test.PostgrexTypes"
    assert diff(igniter) =~ "CREATE EXTENSION IF NOT EXISTS vector"
  end

  test "pgvector reuses an existing add_extensions migration" do
    migration = """
    defmodule Test.Repo.Migrations.AddExtensions do
      use Ecto.Migration

      def up do
        execute "CREATE EXTENSION IF NOT EXISTS citext"
      end

      def down do
        execute "DROP EXTENSION IF EXISTS citext"
      end
    end
    """

    igniter =
      test_project(
        files: %{"priv/repo/migrations/20260101000000_add_extensions.exs" => migration}
      )
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.Pgvector)

    diff = diff(igniter, only: "priv/repo/migrations/20260101000000_add_extensions.exs")
    assert diff =~ "CREATE EXTENSION IF NOT EXISTS vector"
    refute diff(igniter) =~ ~r/\d+_add_extensions\.exs.*\d+_add_extensions\.exs/s
  end

  # Stands in for what `oban.install` (Oban 2.24+) leaves behind.
  defp project_with_oban_configured do
    phx_test_project()
    |> Igniter.Project.Deps.add_dep({:oban, "~> 2.24"})
    |> Igniter.Project.Config.configure(
      "config.exs",
      :test,
      [Oban],
      {:code,
       quote(
         do: [
           engine: Oban.Engines.Postgres,
           notifier: Oban.Notifiers.Postgres,
           queues: [default: 10],
           lifeline: [rescue_after: {2, :hours}],
           pruner: [max_age: {1, :day}],
           repo: Test.Repo
         ]
       )}
    )
  end

  test "oban_pro configures the Pro engine and services when oban is set up" do
    igniter = Igniter.compose_task(project_with_oban_configured(), Mix.Tasks.Starter.Add.ObanPro)

    mix_diff = diff(igniter, only: "mix.exs")
    assert mix_diff =~ ":oban_pro"
    # Offline fallback requirement (version fetch is disabled in tests)
    assert mix_diff =~ ~s("~> 1.8")

    config_diff = diff(igniter, only: "config/config.exs")
    assert config_diff =~ "engine: Oban.Pro.Engine"
    assert config_diff =~ "cron: {Oban.Pro.Cron, crontab: []}"
    assert config_diff =~ "lifeline: Oban.Pro.Lifeline"
    assert config_diff =~ "pruner: Oban.Pro.Pruner"
    assert config_diff =~ "queues: {Oban.Pro.Queues, sync_mode: :automatic"
    assert config_diff =~ "plugins: [Oban.Pro.Plugins.DynamicPrioritizer]"
    # Oban's installer defaults are superseded, not left alongside Pro's...
    refute config_diff =~ "rescue_after"
    refute config_diff =~ "max_age"
    # ...while what it wrote and Pro doesn't care about survives.
    assert config_diff =~ "repo: Test.Repo"
    refute config_diff =~ "Smart"
    refute config_diff =~ "Dynamic" <> "Queues"

    assert diff(igniter) =~ "Oban.Pro.Migration.up()"
  end

  test "oban_pro warns and skips when oban is missing" do
    igniter = Igniter.compose_task(phx_test_project(), Mix.Tasks.Starter.Add.ObanPro)

    assert Enum.any?(igniter.warnings, &(&1 =~ "Oban setup that isn't here yet"))
    refute diff(igniter, only: "mix.exs") =~ ":oban_pro"
  end

  # A starter adds every package it installs to mix.exs before any step runs,
  # so the dep alone says nothing about whether oban.install has composed yet.
  # Guarding on the dep would let this through and clobber Oban's config.
  test "oban_pro warns and skips when oban is a dep but not yet configured" do
    igniter =
      phx_test_project()
      |> Igniter.Project.Deps.add_dep({:oban, "~> 2.24"})
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.ObanPro)

    assert Enum.any?(igniter.warnings, &(&1 =~ "Oban setup that isn't here yet"))
    refute diff(igniter, only: "mix.exs") =~ ":oban_pro"
  end
end
