defmodule StarterNewFixture.SharedStarter do
  use Starter

  @impl Starter
  def steps do
    [
      {:remove, :topbar},
      {:add, :pgvector, if: :pgvector},
      {:install, :oban},
      {:queue, "starter_jamil.oban_tweaks"},
      {:starter, StarterNewFixture.NestedStarter},
      StarterNewFixture.CustomStep
    ]
  end
end

defmodule Mix.Tasks.Starter.NewTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  defp generated_starter do
    igniter =
      test_project()
      |> Igniter.compose_task(Mix.Tasks.Starter.New)

    assert_creates(igniter, "lib/mix/tasks/test.starter.ex")

    igniter.rewrite
    |> Rewrite.source!("lib/mix/tasks/test.starter.ex")
    |> Rewrite.Source.get(:content)
  end

  test "generates a syntactically valid starter module" do
    content = generated_starter()

    assert {:ok, _ast} = Code.string_to_quoted(content)
    assert content =~ "defmodule Mix.Tasks.Test.Starter do"
    assert content =~ "use Starter"
  end

  test "guards the module so other envs compile without starter" do
    content = generated_starter()

    assert content =~ "if Code.ensure_loaded?(Starter) do"
    # The guard must wrap the defmodule, not sit inside it
    assert :binary.match(content, "if Code.ensure_loaded?") <
             :binary.match(content, "defmodule Mix.Tasks.Test.Starter")
  end

  test "generated source is formatted" do
    content = generated_starter()

    formatted = content |> Code.format_string!() |> IO.iodata_to_binary() |> Kernel.<>("\n")
    assert content == formatted
  end

  test "every step carries its description from the module's @shortdoc" do
    content = generated_starter()

    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Remove.DaisyUi)}\n"
    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Add.Pgvector)}\n"
    assert content =~ "# #{Mix.Task.shortdoc(Mix.Tasks.Starter.Gen.BaseSchema)}\n"
  end

  # Packages with their own installers are written as {:add, ...} like any
  # other, and say so in the generated comment — whether a package has an
  # installer is not something the starter file should encode.
  test "packages with their own installers are ordinary {:add, ...} steps" do
    content = generated_starter()

    assert content =~ "{:add, :oban}"
    assert content =~ "{:add, :oban_web}"
    assert content =~ "{:add, :tidewave}"
    assert content =~ "Installs oban and runs the package's own igniter installer"
    refute content =~ "{:install,"
  end

  test "optional steps document their flag" do
    content = generated_starter()

    assert content =~ "(only with --oban-pro)"
    assert content =~ "{:add, :oban_pro, if: :oban_pro}"
    assert content =~ "(only with --gigalixir)"
  end

  test "oban_pro follows oban, whose installer it patches" do
    content = generated_starter()

    {oban_pos, _} = :binary.match(content, "{:add, :oban}")
    {pro_pos, _} = :binary.match(content, "{:add, :oban_pro")
    assert oban_pos < pro_pos
  end

  test "sort_deps runs in-run and last, so it sorts installer-added deps" do
    content = generated_starter()

    assert content =~ "{:gen, :sort_deps}"
    refute content =~ ~s({:queue, "starter.gen.sort_deps")

    {sort_pos, _} = :binary.match(content, "{:gen, :sort_deps}")
    {oban_pos, _} = :binary.match(content, "{:add, :oban}")
    assert oban_pos < sort_pos
  end

  describe "--from" do
    defp generated_from_shared do
      igniter =
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.New, [
          "--from",
          "StarterNewFixture.SharedStarter"
        ])

      assert_creates(igniter, "lib/mix/tasks/test.starter.ex")

      igniter.rewrite
      |> Rewrite.source!("lib/mix/tasks/test.starter.ex")
      |> Rewrite.Source.get(:content)
    end

    test "expands the shared starter's steps instead of the catalog" do
      content = generated_from_shared()

      assert {:ok, _} = Code.string_to_quoted(content)
      assert content =~ "{:remove, :topbar}"
      assert content =~ "{:add, :pgvector, if: :pgvector}"
      assert content =~ "{:install, :oban}"
      assert content =~ ~s({:queue, "starter_jamil.oban_tweaks", []})
      assert content =~ "{:starter, StarterNewFixture.NestedStarter}"
      assert content =~ "StarterNewFixture.CustomStep"
      assert content =~ "from `StarterNewFixture.SharedStarter`"
      # Catalog-only steps are absent
      refute content =~ ":daisy_ui"
      refute content =~ ":gigalixir"
    end

    test "raises with guidance for non-starter modules" do
      assert_raise Mix.Error, ~r/is not a starter/, fn ->
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.New, ["--from", "String"])
      end
    end
  end

  test "the generated starter references only resolvable steps" do
    content = generated_starter()

    # {:add, ...} is exempt: a name with no built-in step is installed as a
    # package, which is how oban and friends appear here.
    Regex.scan(~r/\{:(remove|gen), :(\w+)/, content)
    |> Enum.each(fn [_, kind, name] ->
      kind = String.to_existing_atom(kind)

      assert {:ok, _module} = Starter.Steps.resolve(kind, name),
             "generated starter references unknown step {:#{kind}, :#{name}}"
    end)
  end
end
