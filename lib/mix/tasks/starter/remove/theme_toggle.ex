defmodule Mix.Tasks.Starter.Remove.ThemeToggle do
  @shortdoc "Removes the theme toggle"
  @moduledoc """
  Removes the theme toggle that `phx.new` generates: the theme scripts in the
  root layout, and the `theme_toggle` component and its usage in `Layouts`.
  """
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()

    igniter
    |> remove_from_root_layout(app_web)
    |> remove_from_layouts_module(app_web)
  end

  defp remove_from_root_layout(igniter, app_web) do
    path = "lib/#{app_web}/components/layouts/root.html.heex"

    Helpers.update_file_checked(
      igniter,
      path,
      &remove_theme_scripts/1,
      "no theme scripts were found in #{path}. Either the theme toggle was " <>
        "already removed, or phx.new's output has changed and this step needs " <>
        "updating. Nothing was modified."
    )
  end

  defp remove_from_layouts_module(igniter, app_web) do
    path = "lib/#{app_web}/components/layouts.ex"

    Helpers.update_file_checked(
      igniter,
      path,
      fn content ->
        content
        |> remove_theme_toggle_function()
        |> remove_theme_toggle_usage()
      end,
      "no theme_toggle component was found in #{path}. Either the theme toggle " <>
        "was already removed, or phx.new's output has changed and this step " <>
        "needs updating. Nothing was modified."
    )
  end

  defp remove_theme_scripts(content) do
    # Match script tags without crossing into other script tags, including surrounding whitespace
    regex =
      ~r/\n?\s*<script(?:\s[^>]*)?>(?:(?!<script)(?!<\/script>).)*theme(?:(?!<script)(?!<\/script>).)*<\/script>\s*/si

    content
    |> String.replace(regex, "\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp remove_theme_toggle_usage(content) do
    content
    # Remove a wrapping <li> when it only contains the theme toggle
    |> String.replace(~r/\n\s*<li>\s*<\.theme_toggle\s*\/>\s*<\/li>/, "")
    # Fall back to removing a bare usage line
    |> String.replace(~r/^.*<\.theme_toggle\s*\/>.*\n/m, "")
  end

  defp remove_theme_toggle_function(content) do
    String.replace(
      content,
      ~r/\n\s*@doc\s+"""[^"]*theme[^"]*"""\s*\n\s*def theme_toggle\(assigns\) do\s*\n\s*~H"""[\s\S]*?"""\s*\n\s*end/i,
      ""
    )
  end
end
