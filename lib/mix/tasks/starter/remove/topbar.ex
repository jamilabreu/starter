defmodule Mix.Tasks.Starter.Remove.Topbar do
  @shortdoc "Removes the topbar progress indicator"
  @moduledoc "Removes the topbar progress indicator that `phx.new` generates."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> remove_vendor_file()
    |> edit_app_js()
  end

  defp remove_vendor_file(igniter) do
    path = "assets/vendor/topbar.js"

    if Igniter.exists?(igniter, path) do
      Igniter.rm(igniter, path)
    else
      Igniter.add_warning(igniter, "#{path} not found — skipped removing it.")
    end
  end

  defp edit_app_js(igniter) do
    Helpers.update_file_checked(
      igniter,
      "assets/js/app.js",
      &strip_topbar/1,
      "no topbar references were found in assets/js/app.js. " <>
        "Either topbar was already removed, or phx.new's output has changed " <>
        "and this step needs updating. Nothing was modified."
    )
  end

  defp strip_topbar(content) do
    content
    |> String.split("\n")
    |> Enum.reject(&String.contains?(&1, ["topbar", "progress bar"]))
    |> Enum.join("\n")
    |> then(&Regex.replace(~r/\n{3,}/, &1, "\n\n"))
  end
end
