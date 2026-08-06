defmodule Starter.WorkflowTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defmodule InnerWorkflow do
    use Starter.Workflow

    @impl Starter.Workflow
    def steps do
      [{:add, :credo, if: :credo}]
    end
  end

  defmodule TestWorkflow do
    use Starter.Workflow

    @impl Starter.Workflow
    def steps do
      [
        {:gen, :gitignore},
        {:workflow, InnerWorkflow}
      ]
    end
  end

  defmodule BrokenWorkflow do
    use Starter.Workflow

    @impl Starter.Workflow
    def steps do
      [{:remove, :does_not_exist}]
    end
  end

  defmodule TypoWorkflow do
    use Starter.Workflow

    @impl Starter.Workflow
    def steps do
      [{:add, :credoo}]
    end
  end

  defmodule UnknownAddWorkflow do
    use Starter.Workflow

    @impl Starter.Workflow
    def steps do
      [{:add, :some_unrelated_package}]
    end
  end

  describe "flags/1" do
    test "collects if: flags, including from nested workflows" do
      assert Starter.Workflow.flags_of(TestWorkflow) == [:credo]
    end

    test "flags accumulate across step forms" do
      steps = [
        {:add, :oban, if: :oban},
        {:task, "igniter.install", ["ash"], if: :ash},
        {SomeModule, if: :custom},
        {:gen, :gitignore}
      ]

      assert Starter.Workflow.flags(steps) == [:oban, :ash, :custom]
    end
  end

  describe "Runner.run/3" do
    test "runs unconditional steps and skips flagged steps by default" do
      igniter = Starter.Runner.run(test_project(), TestWorkflow, [])

      assert Igniter.Test.diff(igniter, only: ".gitignore") =~ ".DS_Store"
      refute Igniter.Test.diff(igniter, only: "mix.exs") =~ ":credo"
    end

    test "includes flagged steps (through nested workflows) when the flag is set" do
      igniter = Starter.Runner.run(test_project(), TestWorkflow, credo: true)

      assert Igniter.Test.diff(igniter, only: "mix.exs") =~ ":credo"
    end

    test "unknown remove steps raise with the available step names" do
      assert_raise Mix.Error, ~r/Unknown remove step: :does_not_exist/, fn ->
        Starter.Runner.run(test_project(), BrokenWorkflow, [])
      end
    end

    # `{:add, name}` falls through to installing `name` as a package, so an
    # unrecognized name is not an error on its own — but a near-miss of a
    # built-in step is a typo, not a package anyone meant to install.
    test "add steps that look like a mistyped built-in step raise a suggestion" do
      assert_raise Mix.Error, ~r/Did you mean: credo\?/, fn ->
        Starter.Runner.run(test_project(), TypoWorkflow, [])
      end
    end

    test "add steps with no built-in match resolve to an install" do
      assert Starter.Runner.installs(UnknownAddWorkflow) == [:some_unrelated_package]
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
      igniter = Starter.Runner.run(project_with_phoenix("~> 1.7.14"), TestWorkflow, [])

      assert Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end

    test "does not warn on the supported series" do
      igniter = Starter.Runner.run(project_with_phoenix("~> 1.8.8"), TestWorkflow, [])

      refute Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end

    test "does not warn when Phoenix is not a dependency" do
      igniter = Starter.Runner.run(test_project(), TestWorkflow, [])

      refute Enum.any?(igniter.warnings, &(&1 =~ "supports only the latest stable Phoenix"))
    end
  end
end
