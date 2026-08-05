defmodule Mix.Tasks.Starter.Add.DotenvParser do
  @shortdoc "Adds DotenvParser for .env files"
  @moduledoc "Adds `dotenv_parser` to load environment variables from a `.env` file."
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> create_env_file()
    |> edit_runtime_exs()
    |> edit_gitignore()
  end

  defp add_dep(igniter) do
    Igniter.Project.Deps.add_dep(igniter, Starter.Versions.latest_hex_dep(:dotenv_parser))
  end

  defp create_env_file(igniter) do
    if Igniter.exists?(igniter, ".env") do
      igniter
    else
      Igniter.create_new_file(igniter, ".env", "VARIABLE=value")
    end
  end

  defp edit_runtime_exs(igniter) do
    code = """
    if Code.ensure_loaded?(DotenvParser) and File.exists?(".env") do
      DotenvParser.load_file(".env")
    end
    """

    Igniter.create_or_update_elixir_file(
      igniter,
      "config/runtime.exs",
      "import Config\n\n" <> code,
      fn zipper ->
        case Sourceror.Zipper.search_pattern(zipper, "import Config") do
          nil -> {:ok, Igniter.Code.Common.add_code(zipper, code, placement: :after)}
          found -> {:ok, Igniter.Code.Common.add_code(found, code, placement: :after)}
        end
      end
    )
  end

  defp edit_gitignore(igniter) do
    Igniter.update_file(igniter, ".gitignore", fn source ->
      content = Rewrite.Source.get(source, :content)

      if String.contains?(content, ".env") do
        source
      else
        content = String.trim_trailing(content) <> "\n\n# Environment variables\n.env\n"
        Rewrite.Source.update(source, :content, content)
      end
    end)
  end
end
