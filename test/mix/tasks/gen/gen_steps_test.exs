defmodule Mix.Tasks.Starter.Gen.StepsTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "schema" do
    test "generates with :binary_id by default" do
      igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Gen.BaseSchema)

      assert diff(igniter, only: "lib/test/schema.ex") =~
               "@primary_key {:id, :binary_id, autogenerate: true}"
    end

    test "uses UUIDv7 when the uuidv7 dep is present" do
      igniter =
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.Add.Uuidv7)
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.BaseSchema)

      assert diff(igniter, only: "lib/test/schema.ex") =~
               "@primary_key {:id, UUIDv7, autogenerate: true}"
    end
  end

  describe "sort_deps" do
    defp sorted_mix_exs(deps_block) do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [app: :test, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
      #{deps_block}
          ]
        end
      end
      """

      test_project(files: %{"mix.exs" => mix_exs})
      |> Igniter.compose_task(Mix.Tasks.Starter.Gen.SortDeps)
      |> apply_igniter!()
      |> Map.get(:rewrite)
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:content)
    end

    test "sorts alphabetically, preserving multi-line formatting exactly" do
      content =
        sorted_mix_exs("""
              {:phoenix, "~> 1.8.8"},
              {:bandit, "~> 1.5"},
              {:heroicons,
               github: "tailwindlabs/heroicons",
               tag: "v2.2.0",
               sparse: "optimized"},
              {:ecto_sql, "~> 3.13"}\
        """)

      expected =
        Enum.join(
          [
            ~s(      {:bandit, "~> 1.5"},),
            ~s(      {:ecto_sql, "~> 3.13"},),
            ~s(      {:heroicons,),
            ~s(       github: "tailwindlabs/heroicons",),
            ~s(       tag: "v2.2.0",),
            ~s(       sparse: "optimized"},),
            ~s(      {:phoenix, "~> 1.8.8"})
          ],
          "\n"
        )

      assert content =~ expected

      # The file still parses and no dep was lost
      assert {:ok, _} = Code.string_to_quoted(content)
    end

    test "keeps comments attached and never swallows the following dep" do
      content =
        sorted_mix_exs("""
              {:phoenix, "~> 1.8.8"},
              # {:dep_from_hexpm, "~> 0.3.0"},
              {:ecto_sql, "~> 3.13"},
              {:bandit, "~> 1.5"}\
        """)

      # All three real deps survive
      assert content =~ ~s({:phoenix, "~> 1.8.8"})
      assert content =~ ~s({:ecto_sql, "~> 3.13"})
      assert content =~ ~s({:bandit, "~> 1.5"})
      # The comment rides with ecto_sql (the dep it precedes)
      assert content =~ ~r/# \{:dep_from_hexpm, "~> 0\.3\.0"\},\n\s*\{:ecto_sql/
    end

    test "is a no-op on an already sorted list" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [app: :test, version: "0.1.0", deps: deps()]
        end

        defp deps do
          [
            {:bandit, "~> 1.5"},
            {:phoenix, "~> 1.8.8"}
          ]
        end
      end
      """

      test_project(files: %{"mix.exs" => mix_exs})
      |> Igniter.compose_task(Mix.Tasks.Starter.Gen.SortDeps)
      |> assert_unchanged("mix.exs")
    end

    test "handles UTF-8 and commas inside strings" do
      content =
        sorted_mix_exs("""
              {:phoenix, "~> 1.8.8"},
              # ünïcode cömment
              {:bandit, "~> 1.5", hex: "bandit, the great"}\
        """)

      assert content =~ ~s({:bandit, "~> 1.5", hex: "bandit, the great"})
      assert content =~ "ünïcode cömment"
      assert {:ok, _} = Code.string_to_quoted(content)
    end
  end

  describe "force_drop" do
    test "rewrites the ecto.drop alias" do
      mix_exs = """
      defmodule Test.MixProject do
        use Mix.Project

        def project do
          [app: :test, version: "0.1.0", aliases: aliases(), deps: []]
        end

        defp aliases do
          [
            "ecto.reset": ["ecto.drop", "ecto.setup"]
          ]
        end
      end
      """

      igniter =
        test_project(files: %{"mix.exs" => mix_exs})
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.EctoForceDrop)

      assert diff(igniter, only: "mix.exs") =~ "ecto.drop --force-drop"
    end
  end

  describe "env_config" do
    test "adds env: Mix.env() to config.exs" do
      igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Gen.MixEnvConfig)

      assert diff(igniter, only: "config/config.exs") =~ "env: Mix.env()"
    end
  end

  describe "repo_config" do
    test "configures generators and migration timestamps" do
      igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Gen.GeneratorDefaults)

      config_diff = diff(igniter, only: "config/config.exs")
      assert config_diff =~ "timestamp_type: :utc_datetime_usec"
      assert config_diff =~ "binary_id: true"
      assert config_diff =~ "migration_timestamps"
    end
  end

  describe "pg_extensions" do
    test "generates the extensions migration" do
      igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Gen.PgExtensions)

      diff = diff(igniter)
      assert diff =~ "add_extensions.exs"
      assert diff =~ "CREATE EXTENSION IF NOT EXISTS citext"
      assert diff =~ "f_unaccent"
    end
  end

  describe "home_page" do
    test "replaces an existing home page" do
      igniter =
        test_project(
          files: %{"lib/test_web/controllers/page_html/home.html.heex" => "<div>old</div>\n"}
        )
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.MinimalHomePage)

      assert diff(igniter, only: "lib/test_web/controllers/page_html/home.html.heex") =~
               "Layouts.app"
    end

    test "warns instead of creating when the page is missing" do
      igniter = Igniter.compose_task(test_project(), Mix.Tasks.Starter.Gen.MinimalHomePage)

      assert Enum.any?(igniter.warnings, &(&1 =~ "skipped generating the home page"))
    end
  end

  describe "gigalixir" do
    test "creates deployment files without the Oban Pro hook by default" do
      igniter = Igniter.compose_task(phx_test_project(), Mix.Tasks.Starter.Gen.Gigalixir)

      diff = diff(igniter)
      assert diff =~ "elixir_buildpack.config"
      assert diff =~ "erlang_version="
      assert diff =~ "gigalixir-buildpack-elixir"
      assert diff =~ "rel/overlays/Procfile"
      assert diff =~ "Ecto.Migrator.with_repo"
      refute diff =~ "OBAN_PRO_AUTH_KEY"
    end

    test "includes the Oban Pro hook when oban_pro is a dependency" do
      igniter =
        phx_test_project()
        |> Igniter.Project.Deps.add_dep({:oban_pro, "~> 1.7.0-rc", repo: "oban"})
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gigalixir)

      assert diff(igniter) =~ "OBAN_PRO_AUTH_KEY"
    end
  end
end
