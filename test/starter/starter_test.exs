defmodule StarterTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defmodule InnerStarter do
    use Starter

    @impl Starter
    def steps do
      [{:add, :credo, if: :credo}]
    end
  end

  defmodule TestStarter do
    use Starter

    @impl Starter
    def steps do
      [
        {:gen, :gitignore},
        {:starter, InnerStarter}
      ]
    end
  end

  defmodule BrokenStarter do
    use Starter

    @impl Starter
    def steps do
      [{:remove, :does_not_exist}]
    end
  end

  defmodule TypoStarter do
    use Starter

    @impl Starter
    def steps do
      [{:add, :credoo}]
    end
  end

  defmodule UnknownAddStarter do
    use Starter

    @impl Starter
    def steps do
      [{:add, :some_unrelated_package}]
    end
  end

  describe "flags/1" do
    test "collects if: flags, including from nested starters" do
      assert Starter.flags_of(TestStarter) == [:credo]
    end

    test "flags accumulate across step forms" do
      steps = [
        {:add, :oban, if: :oban},
        {:task, "igniter.install", ["ash"], if: :ash},
        {SomeModule, if: :custom},
        {:gen, :gitignore}
      ]

      assert Starter.flags(steps) == [:oban, :ash, :custom]
    end
  end

  describe "Runner.run/3" do
    test "runs unconditional steps and skips flagged steps by default" do
      igniter = Starter.Runner.run(test_project(), TestStarter, [])

      assert Igniter.Test.diff(igniter, only: ".gitignore") =~ ".DS_Store"
      refute Igniter.Test.diff(igniter, only: "mix.exs") =~ ":credo"
    end

    test "includes flagged steps (through nested starters) when the flag is set" do
      igniter = Starter.Runner.run(test_project(), TestStarter, credo: true)

      assert Igniter.Test.diff(igniter, only: "mix.exs") =~ ":credo"
    end

    test "unknown remove steps raise with the available step names" do
      assert_raise Mix.Error, ~r/Unknown remove step: :does_not_exist/, fn ->
        Starter.Runner.run(test_project(), BrokenStarter, [])
      end
    end

    # `{:add, name}` falls through to installing `name` as a package, so an
    # unrecognized name is not an error on its own — but a near-miss of a
    # built-in step is a typo, not a package anyone meant to install.
    test "add steps that look like a mistyped built-in step raise a suggestion" do
      assert_raise Mix.Error, ~r/Did you mean: credo\?/, fn ->
        Starter.Runner.run(test_project(), TypoStarter, [])
      end
    end

    test "add steps with no built-in match resolve to an install" do
      assert Starter.Runner.installs(UnknownAddStarter) == [:some_unrelated_package]
    end
  end

  describe "Phoenix version guard" do
    defp project_with_phoenix(requirement) do
      test_project(
        files: %{
          "mix.exs" => """
          defmodule Test.MixProject do
            use Mix.Project

            def project do
              [app: :test, version: "0.1.0", deps: deps()]
            end

            defp deps do
              [
                {:phoenix, "#{requirement}"}
              ]
            end
          end
          """
        }
      )
    end

    test "warns when the app's Phoenix is older than the supported series" do
      igniter = Starter.Runner.run(project_with_phoenix("~> 1.7.14"), TestStarter, [])

      assert Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end

    test "does not warn on the supported series" do
      igniter = Starter.Runner.run(project_with_phoenix("~> 1.8.8"), TestStarter, [])

      refute Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end

    test "does not warn when Phoenix is not a dependency" do
      igniter = Starter.Runner.run(test_project(), TestStarter, [])

      refute Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end
  end
end
