defmodule StarterNewFixture.SharedWorkflow do
  use Starter.Workflow

  @impl Starter.Workflow
  def steps do
    [
      {:remove, :topbar},
      {:add, :pgvector, if: :pgvector},
      {:install, :oban},
      {:queue, "starter_jamil.oban_tweaks"},
      {:workflow, StarterNewFixture.NestedWorkflow},
      StarterNewFixture.CustomStep
    ]
  end
end

defmodule Mix.Tasks.Starter.NewTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defp generated_workflow do
    igniter =
      test_project()
      |> Igniter.compose_task(Mix.Tasks.Starter.New)

    assert_creates(igniter, "lib/mix/tasks/test.workflow.ex")

    igniter.rewrite
    |> Rewrite.source!("lib/mix/tasks/test.workflow.ex")
    |> Rewrite.Source.get(:content)
  end

  test "generates a syntactically valid workflow module" do
    content = generated_workflow()

    assert {:ok, _ast} = Code.string_to_quoted(content)
    assert content =~ "defmodule Mix.Tasks.Test.Workflow do"
    assert content =~ "use Starter.Workflow"
  end

  test "guards the module so other envs compile without starter" do
    content = generated_workflow()

    assert content =~ "if Code.ensure_loaded?(Starter.Workflow) do"
    # The guard must wrap the defmodule, not sit inside it
    assert :binary.match(content, "if Code.ensure_loaded?") <
             :binary.match(content, "defmodule Mix.Tasks.Test.Workflow")
  end

  test "generated source is formatted" do
    content = generated_workflow()

    formatted = content |> Code.format_string!() |> IO.iodata_to_binary() |> Kernel.<>("\n")
    assert content == formatted
  end

  test "every step carries its description from the module's @shortdoc" do
    content = generated_workflow()

    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Remove.DaisyUi)}\n"
    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Add.Pgvector)}\n"
    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Gen.BaseSchema)}\n"
  end

  test "packages with their own installers use {:install, ...}" do
    content = generated_workflow()

    assert content =~ "{:install, :oban}"
    assert content =~ "{:install, :oban_web}"
    assert content =~ "{:install, :tidewave}"
    refute content =~ "{:add, :oban}"
    refute content =~ "{:add, :tidewave}"
  end

  test "optional steps document their flag" do
    content = generated_workflow()

    assert content =~ "(only with --oban-pro)"
    assert content =~ ~s({:queue, "starter.add", ["oban_pro"], if: :oban_pro})
    assert content =~ "(only with --gigalixir)"
  end

  describe "--from" do
    defp generated_from_shared do
      igniter =
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.New, [
          "--from",
          "StarterNewFixture.SharedWorkflow"
        ])

      assert_creates(igniter, "lib/mix/tasks/test.workflow.ex")

      igniter.rewrite
      |> Rewrite.source!("lib/mix/tasks/test.workflow.ex")
      |> Rewrite.Source.get(:content)
    end

    test "expands the shared workflow's steps instead of the catalog" do
      content = generated_from_shared()

      assert {:ok, _} = Code.string_to_quoted(content)
      assert content =~ "{:remove, :topbar}"
      assert content =~ "{:add, :pgvector, if: :pgvector}"
      assert content =~ "{:install, :oban}"
      assert content =~ ~s({:queue, "starter_jamil.oban_tweaks", []})
      assert content =~ "{:workflow, StarterNewFixture.NestedWorkflow}"
      assert content =~ "StarterNewFixture.CustomStep"
      assert content =~ "from `StarterNewFixture.SharedWorkflow`"
      # Catalog-only steps are absent
      refute content =~ ":daisy_ui"
      refute content =~ ":gigalixir"
    end

    test "raises with guidance for non-workflow modules" do
      assert_raise Mix.Error, ~r/is not a Starter workflow/, fn ->
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.New, ["--from", "String"])
      end
    end
  end

  test "the generated workflow references only resolvable steps" do
    content = generated_workflow()

    Regex.scan(~r/\{:(add|remove|gen), :(\w+)/, content)
    |> Enum.each(fn [_, kind, name] ->
      kind = String.to_existing_atom(kind)

      assert {:ok, _module} = Starter.Steps.resolve(kind, name),
             "generated workflow references unknown step {:#{kind}, :#{name}}"
    end)
  end
end
