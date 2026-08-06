defmodule Mix.Tasks.Starter.Gen.Gitignore do
  @shortdoc "Adds macOS system files to .gitignore"
  @moduledoc "Adds macOS system files to `.gitignore`, creating the file if needed."
  use Igniter.Mix.Task

  @entry "\n# Ignore macOS system files\n.DS_Store\n"

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    if Igniter.exists?(igniter, ".gitignore") do
      Starter.Helpers.update_file_content(igniter, ".gitignore", fn content ->
        if String.contains?(content, ".DS_Store") do
          content
        else
          String.trim_trailing(content) <> "\n" <> @entry
        end
      end)
    else
      Igniter.create_new_file(igniter, ".gitignore", String.trim_leading(@entry))
    end
  end
end
