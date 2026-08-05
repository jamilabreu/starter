defmodule Mix.Tasks.Starter.Remove.DaisyUi do
  @shortdoc "Removes daisyUI"
  @moduledoc "Removes the `:daisyui` Mix dependency and the CSS plugin blocks that `phx.new` generates."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> remove_mix_dep()
    |> edit_app_css()
  end

  defp remove_mix_dep(igniter) do
    if Igniter.Project.Deps.has_dep?(igniter, :daisyui) do
      Igniter.Project.Deps.remove_dep(igniter, :daisyui)
    else
      igniter
    end
  end

  defp edit_app_css(igniter) do
    Helpers.update_file_checked(
      igniter,
      "assets/css/app.css",
      &strip_daisyui/1,
      "no daisyUI plugin blocks were found in assets/css/app.css. " <>
        "Either daisyUI was already removed, or phx.new's output has changed " <>
        "and this step needs updating. Nothing was modified."
    )
  end

  defp strip_daisyui(content) do
    content
    |> remove_commented_plugin_blocks()
    |> remove_orphan_plugin_blocks()
  end

  # A daisyUI comment directly followed by a daisyui @plugin block. The
  # comment interior pattern stays within a single /* ... */ comment.
  defp remove_commented_plugin_blocks(content) do
    Regex.replace(
      ~r/\/\* daisyUI(?:[^*]|\*(?!\/))*\*\/\n@plugin "[^"]*daisyui[^"]*"(?: \{[^}]*\}|;)\n+/,
      content,
      ""
    )
  end

  # Any remaining daisyui @plugin blocks without a leading comment
  defp remove_orphan_plugin_blocks(content) do
    Regex.replace(
      ~r/@plugin "[^"]*daisyui[^"]*"(?: \{[^}]*\}|;)\n+/,
      content,
      ""
    )
  end
end
