defmodule Starter.HelpersTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defp migration_versions(igniter) do
    igniter.rewrite
    |> Rewrite.paths()
    |> Enum.filter(&String.match?(&1, ~r{priv/repo/migrations/}))
    |> Enum.map(&(&1 |> Path.basename() |> Integer.parse() |> elem(0)))
    |> Enum.sort()
  end

  describe "gen_migration/4" do
    test "advances past migrations another task created earlier in the same run" do
      # A package's installer composes into the same run now, so its migration
      # is already in the rewrite when our step generates one. A far-future
      # version proves the timestamp is read rather than assumed from the clock.
      existing = 29_990_101_000_000

      igniter =
        phx_test_project()
        |> Igniter.create_new_file(
          "priv/repo/migrations/#{existing}_add_oban.exs",
          "defmodule Test.Repo.Migrations.AddOban do\nend\n"
        )
        |> Starter.Helpers.gen_migration(Test.Repo, "add_oban_pro",
          body: "def up, do: :ok\ndef down, do: :ok\n"
        )

      versions = migration_versions(igniter)

      assert length(versions) == 2
      assert Enum.uniq(versions) == versions, "migration versions collided: #{inspect(versions)}"
      assert Enum.max(versions) > existing
    end

    test "successive migrations in one run get distinct versions" do
      igniter =
        Enum.reduce(["add_one", "add_two", "add_three"], phx_test_project(), fn name, igniter ->
          Starter.Helpers.gen_migration(igniter, Test.Repo, name, body: "def change, do: :ok\n")
        end)

      versions = migration_versions(igniter)

      assert length(versions) == 3
      assert Enum.uniq(versions) == versions, "migration versions collided: #{inspect(versions)}"
    end
  end
end
