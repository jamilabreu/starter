defmodule Starter.ReviewFixesTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "updater fallbacks no longer crash" do
    test "dotenv_parser appends config when runtime.exs lacks import Config" do
      runtime = """
      if System.get_env("PHX_SERVER") do
        :ok
      end
      """

      igniter =
        test_project(files: %{"config/runtime.exs" => runtime})
        |> Igniter.compose_task(Mix.Tasks.Starter.Add.DotenvParser)

      assert diff(igniter, only: "config/runtime.exs") =~ "DotenvParser.load_file"
    end

    test "minimal_app_layout warns instead of crashing when app/1 is missing" do
      layouts = """
      defmodule TestWeb.Layouts do
        def something_else(assigns), do: assigns
      end
      """

      igniter =
        test_project(files: %{"lib/test_web/components/layouts.ex" => layouts})
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.MinimalAppLayout)

      assert Enum.any?(igniter.warnings, &(&1 =~ "has no app/1 function"))
    end

    test "tailwind_formatter is idempotent instead of crashing on re-run" do
      igniter =
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.TailwindFormatter)
        |> apply_igniter!()
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.TailwindFormatter)

      assert_unchanged(igniter, ".formatter.exs")
    end
  end

  describe "bun package.json merge" do
    test "preserves existing user dependencies" do
      package_json = """
      {
        "workspaces": ["packages/*"],
        "dependencies": {
          "chart.js": "^4.0.0"
        }
      }
      """

      igniter =
        phx_test_project(files: %{"assets/package.json" => package_json})
        |> Igniter.compose_task(Mix.Tasks.Starter.Add.Bun)

      # JSON is re-encoded (keys sorted), so assert the user's dep survives
      # on the + side alongside ours, and the user's workspace entry remains.
      diff = diff(igniter, only: "assets/package.json")
      assert diff =~ ~r/\+\s*\|\s*"chart\.js": "\^4\.0\.0"/
      assert diff =~ "workspace:*"
      assert diff =~ ~s("packages/*")
    end
  end

  describe "workflow step forms" do
    defmodule TaskWorkflow do
      use Starter.Workflow

      @impl Starter.Workflow
      def steps, do: [{:task, "format"}]
    end

    defmodule InstallWorkflow do
      use Starter.Workflow

      @impl Starter.Workflow
      def steps, do: [{:install, :ash}, {:install, :oban_pro, if: :oban_pro}]
    end

    defmodule QueueWorkflow do
      use Starter.Workflow

      @impl Starter.Workflow
      def steps do
        [
          {:install, :oban},
          {:queue, "starter.add", ["oban_pro"], if: :oban_pro}
        ]
      end
    end

    test "non-Igniter {:task, ...} steps warn instead of silently no-oping" do
      igniter = Starter.Runner.run(test_project(), TaskWorkflow, [])

      assert Enum.any?(igniter.warnings, &(&1 =~ "not an Igniter task"))
    end

    test "{:install, pkg} queues igniter.install and honors flags" do
      igniter = Starter.Runner.run(test_project(), InstallWorkflow, [])

      assert Enum.any?(igniter.tasks, fn {task, argv} ->
               task == "igniter.install" and "ash" in argv
             end)

      # Queued subprocesses have no stdin; --yes is always appended so
      # prompting installers cannot stall the run.
      assert Enum.all?(igniter.tasks, fn {_task, argv} -> "--yes" in argv end)

      refute Enum.any?(igniter.tasks, fn {_task, argv} -> "oban_pro" in argv end)

      with_flag = Starter.Runner.run(test_project(), InstallWorkflow, oban_pro: true)

      assert Enum.any?(with_flag.tasks, fn {task, argv} ->
               task == "igniter.install" and "oban_pro" in argv
             end)
    end

    test "{:queue, ...} sequences a task after installs, honoring flags" do
      igniter = Starter.Runner.run(test_project(), QueueWorkflow, oban_pro: true)

      tasks = Enum.map(igniter.tasks, fn {task, _argv} -> task end)
      assert tasks == ["igniter.install", "starter.add"]

      # Exactly the task args plus --yes: the workflow's own flags must not
      # leak into subprocess argv (strict option parsers reject them).
      assert {_, ["oban_pro", "--yes"]} =
               Enum.find(igniter.tasks, fn {task, _} -> task == "starter.add" end)

      assert {_, ["oban", "--yes"]} =
               Enum.find(igniter.tasks, fn {task, _} -> task == "igniter.install" end)

      without_flag = Starter.Runner.run(test_project(), QueueWorkflow, [])
      refute Enum.any?(without_flag.tasks, fn {task, _} -> task == "starter.add" end)

      assert Starter.Workflow.flags_of(QueueWorkflow) == [:oban_pro]
    end
  end

  describe "versions" do
    test "requirement/1 keeps three segments for 0.x, minor series otherwise" do
      assert Starter.Versions.requirement("0.3.1") == "~> 0.3.1"
      assert Starter.Versions.requirement("0.10.2") == "~> 0.10.2"
      assert Starter.Versions.requirement("1.0.0") == "~> 1.0"
      assert Starter.Versions.requirement("2.19.4") == "~> 2.19"
    end

    test "fetch_npm_versions never raises and maps failures to nil" do
      # fetch_versions is disabled in tests, so every lookup returns nil
      assert Starter.Versions.fetch_npm_versions(["tailwindcss", "bun"]) ==
               %{"tailwindcss" => nil, "bun" => nil}
    end

    test "oban_pro version lookup degrades to nil offline" do
      assert Starter.Versions.fetch_oban_pro_version() == nil
    end
  end

  describe "gigalixir colocated hooks" do
    @app_js_standalone """
    import {hooks as colocatedHooks} from "phoenix-colocated/test"
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: {...colocatedHooks},
      params: {_csrf_token: csrfToken}
    })
    """

    @app_js_merged """
    import {hooks as colocatedHooks} from "phoenix-colocated/test"
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: {...colocatedHooks, ...myHooks},
      params: {_csrf_token: csrfToken}
    })
    """

    # phx_test_project's files option cannot override its default files,
    # so seed app.js content by updating and applying first.
    defp project_with_app_js(content) do
      phx_test_project()
      |> Igniter.update_file("assets/js/app.js", fn source ->
        Rewrite.Source.update(source, :content, content)
      end)
      |> apply_igniter!()
    end

    test "removes import and hooks together when standalone" do
      igniter =
        project_with_app_js(@app_js_standalone)
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gigalixir)

      diff = diff(igniter, only: "assets/js/app.js")
      assert diff =~ "- |import {hooks as colocatedHooks}"
      assert Enum.any?(igniter.notices, &(&1 =~ "colocated"))
    end

    test "leaves merged hooks untouched with a warning" do
      igniter =
        project_with_app_js(@app_js_merged)
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gigalixir)

      assert_unchanged(igniter, "assets/js/app.js")
      assert Enum.any?(igniter.warnings, &(&1 =~ "merges colocatedHooks"))
    end

    test "skips removal entirely when bun manages assets" do
      igniter =
        project_with_app_js(@app_js_standalone)
        |> Igniter.Project.Deps.add_dep({:bun, "~> 2.0"})
        |> Igniter.compose_task(Mix.Tasks.Starter.Gen.Gigalixir)

      assert_unchanged(igniter, "assets/js/app.js")
    end
  end
end
