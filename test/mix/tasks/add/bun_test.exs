defmodule Mix.Tasks.Starter.Add.BunTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @tsconfig """
  // This file is needed on most editors.
  {
    "compilerOptions": {
      "baseUrl": ".",
      "paths": {
        "*": ["../deps/*"]
      },
      "allowJs": true,
      "noEmit": true
    },
    "include": ["js/**/*"]
  }
  """

  setup do
    igniter =
      phx_test_project(files: %{"assets/tsconfig.json" => @tsconfig})
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.Bun)

    [igniter: igniter]
  end

  test "swaps esbuild/tailwind for bun in mix.exs", %{igniter: igniter} do
    mix_diff = diff(igniter, only: "mix.exs")
    assert mix_diff =~ ":bun"
  end

  test "creates a package.json with workspace deps", %{igniter: igniter} do
    diff = diff(igniter, only: "assets/package.json")
    assert diff =~ "workspace:*"
    assert diff =~ "tailwindcss"
  end

  test "drops the deps path alias from tsconfig.json", %{igniter: igniter} do
    diff = diff(igniter, only: "assets/tsconfig.json")
    assert diff =~ ~s(- |    "baseUrl")
    assert diff =~ ~s(- |    "paths")
  end

  test "configures bun in config.exs", %{igniter: igniter} do
    config_diff = diff(igniter, only: "config/config.exs")
    assert config_diff =~ "config :bun"
    assert config_diff =~ "tailwindcss --input=css/app.css"
  end

  test "is idempotent on re-run instead of crashing the formatter" do
    igniter =
      phx_test_project()
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.Bun)
      |> apply_igniter!()
      |> Igniter.compose_task(Mix.Tasks.Starter.Add.Bun)

    assert_unchanged(igniter, "config/config.exs")
    assert_unchanged(igniter, "config/dev.exs")
    assert_unchanged(igniter, "mix.exs")
  end
end
