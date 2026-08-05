defmodule Mix.Tasks.Starter.Remove.DaisyUiTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  # Mirrors current phx.new output: daisyUI as a Mix dependency,
  # npm-style @plugin paths, multiline theme comment.
  @app_css """
  @import "tailwindcss" source(none);

  /* A Tailwind plugin for hero icons */
  @plugin "../vendor/heroicons";

  /* daisyUI Tailwind Plugin. */
  @plugin "daisyui/packages/bundle/daisyui" {
    themes: false;
  }

  /* daisyUI theme plugin.
    We ship with two themes, a light one inspired on Phoenix colors and a dark one inspired
    on Elixir colors. Build your own at: https://daisyui.com/theme-generator/ */
  @plugin "daisyui/packages/bundle/daisyui-theme" {
    name: "dark";
    default: false;
    --color-base-100: oklch(30.33% 0.016 252.42);
  }

  @plugin "daisyui/packages/bundle/daisyui-theme" {
    name: "light";
    default: true;
  }

  body {
    background: white;
  }
  """

  @mix_exs """
  defmodule Test.MixProject do
    use Mix.Project

    def project do
      [app: :test, version: "0.1.0", deps: deps()]
    end

    defp deps do
      [
        {:daisyui,
         github: "saadeghi/daisyui",
         tag: "v5.5.20",
         sparse: "packages/bundle",
         app: false,
         compile: false,
         depth: 1}
      ]
    end
  end
  """

  describe "on current phx.new output" do
    setup do
      igniter =
        test_project(
          files: %{
            "mix.exs" => @mix_exs,
            "assets/css/app.css" => @app_css
          }
        )
        |> Igniter.compose_task(Mix.Tasks.Starter.Remove.DaisyUi)

      [igniter: igniter]
    end

    test "strips every daisyUI plugin block, keeping other plugins", %{igniter: igniter} do
      diff = diff(igniter, only: "assets/css/app.css")
      refute diff =~ ~r/\+\s*\|\s*@plugin/
      assert diff =~ ~s(- |@plugin "daisyui/packages/bundle/daisyui")
      assert diff =~ ~s(- |@plugin "daisyui/packages/bundle/daisyui-theme")
      refute diff =~ ~s(- |@plugin "../vendor/heroicons")
    end

    test "removes the :daisyui mix dependency", %{igniter: igniter} do
      assert diff(igniter, only: "mix.exs") =~ ~r/-\s*\|\s*\{:daisyui,/
    end

    test "does not warn", %{igniter: igniter} do
      assert igniter.warnings == []
    end
  end

  describe "drift detection" do
    test "warns loudly instead of silently no-oping when nothing matches" do
      igniter =
        test_project(files: %{"assets/css/app.css" => "body { color: red; }\n"})
        |> Igniter.compose_task(Mix.Tasks.Starter.Remove.DaisyUi)

      assert Enum.any?(igniter.warnings, &(&1 =~ "no daisyUI plugin blocks were found"))
    end

    test "warns when app.css does not exist" do
      igniter =
        test_project()
        |> Igniter.compose_task(Mix.Tasks.Starter.Remove.DaisyUi)

      assert Enum.any?(igniter.warnings, &(&1 =~ "assets/css/app.css not found"))
    end
  end
end
