defmodule Mix.Tasks.Starter.Remove.LiveTitleSuffixTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  # The exact single-line form phx.new 1.8.8 generates
  @root_layout """
  <html>
    <head>
      <.live_title default="Test" suffix=" · Phoenix Framework" phx-no-format>{assigns[:page_title]}</.live_title>
    </head>
  </html>
  """

  test "strips the suffix attribute, keeping the others" do
    igniter =
      test_project(files: %{"lib/test_web/components/layouts/root.html.heex" => @root_layout})
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.LiveTitleSuffix)

    diff = diff(igniter, only: "lib/test_web/components/layouts/root.html.heex")
    refute diff =~ ~r/\+\s*\|.*suffix=/
    assert diff =~ ~r/\+\s*\|.*<\.live_title default="Test" phx-no-format>/
  end

  test "warns loudly when there is no suffix to remove" do
    igniter =
      test_project(
        files: %{"lib/test_web/components/layouts/root.html.heex" => "<html></html>\n"}
      )
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.LiveTitleSuffix)

    assert Enum.any?(igniter.warnings, &(&1 =~ "no <.live_title> suffix was found"))
  end
end
