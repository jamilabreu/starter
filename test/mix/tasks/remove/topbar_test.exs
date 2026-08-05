defmodule Mix.Tasks.Starter.Remove.TopbarTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @app_js """
  import {Socket} from "phoenix"
  import {LiveSocket} from "phoenix_live_view"
  import topbar from "../vendor/topbar"

  // Show progress bar on live navigation and form submits
  topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

  let liveSocket = new LiveSocket("/live", Socket, {})
  liveSocket.connect()
  """

  test "strips topbar lines from app.js and removes the vendor file" do
    igniter =
      test_project(
        files: %{
          "assets/js/app.js" => @app_js,
          "assets/vendor/topbar.js" => "// vendored"
        }
      )
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.Topbar)

    diff = diff(igniter, only: "assets/js/app.js")
    assert diff =~ "- |import topbar"
    assert diff =~ "- |topbar.config"
    refute diff =~ ~r/\+\s*\|.*topbar/

    assert "assets/vendor/topbar.js" in igniter.rms
  end

  test "warns loudly when app.js has no topbar references" do
    igniter =
      test_project(files: %{"assets/js/app.js" => "console.log(\"hi\")\n"})
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.Topbar)

    assert Enum.any?(igniter.warnings, &(&1 =~ "no topbar references were found"))
  end
end
