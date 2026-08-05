defmodule Mix.Tasks.Starter.Remove.LiveTitleSuffix do
  @shortdoc "Removes the live title suffix"
  @moduledoc ~S(Removes the `suffix=" · Phoenix Framework"` attribute from `<.live_title>` in the root layout.)
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web}/components/layouts/root.html.heex"

    Helpers.update_file_checked(
      igniter,
      path,
      &strip_suffix/1,
      "no <.live_title> suffix was found in #{path}. Either it was already " <>
        "removed, or phx.new's output has changed and this step needs updating. " <>
        "Nothing was modified."
    )
  end

  defp strip_suffix(content) do
    String.replace(
      content,
      ~r/<\.live_title([^>]*) suffix="[^"]*"([^>]*)>\s*(\{[^}]+\})\s*<\/\.live_title>/s,
      "<.live_title\\1\\2>\\3</.live_title>"
    )
  end
end
