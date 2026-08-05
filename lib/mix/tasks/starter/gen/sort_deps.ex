defmodule Mix.Tasks.Starter.Gen.SortDeps do
  @shortdoc "Sorts dependencies in mix.exs"
  @moduledoc """
  Sorts the dependencies in `mix.exs` alphabetically by name.

  Preserves each entry's original formatting: multi-line dependencies stay
  multi-line, and comment lines travel with the dependency they precede.
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    Starter.Helpers.update_file_content(igniter, "mix.exs", fn content ->
      Regex.replace(
        ~r/(defp deps do\s*\n\s*\[)([\s\S]*?)(\n\s*\]\s*\n\s*end)/,
        content,
        fn _, prefix, deps_content, suffix ->
          prefix <> sort_deps(deps_content) <> suffix
        end
      )
    end)
  end

  # Entries keep their raw text — leading newline, indentation, attached
  # comments, and multi-line formatting — so sorting only reorders them.
  defp sort_deps(deps_content) do
    deps_content
    |> split_at_top_level_commas([])
    |> Enum.sort_by(&entry_name/1)
    |> Enum.join(",")
  end

  defp split_at_top_level_commas(binary, acc) do
    case find_top_level_comma(binary, 0, 0) do
      nil ->
        Enum.reverse([binary | acc])

      pos ->
        entry = binary_part(binary, 0, pos)
        rest = binary_part(binary, pos + 1, byte_size(binary) - pos - 1)
        split_at_top_level_commas(rest, [entry | acc])
    end
  end

  # Byte-accurate scan for the first comma at bracket depth 0, treating
  # comments (# to end of line) and double-quoted strings as opaque.
  defp find_top_level_comma(<<>>, _pos, _depth), do: nil
  defp find_top_level_comma(<<?,, _::binary>>, pos, 0), do: pos

  defp find_top_level_comma(<<?#, rest::binary>>, pos, depth),
    do: skip_comment(rest, pos + 1, depth)

  defp find_top_level_comma(<<?", rest::binary>>, pos, depth),
    do: skip_string(rest, pos + 1, depth)

  defp find_top_level_comma(<<c, rest::binary>>, pos, depth) when c in ~c"([{",
    do: find_top_level_comma(rest, pos + 1, depth + 1)

  defp find_top_level_comma(<<c, rest::binary>>, pos, depth) when c in ~c")]}",
    do: find_top_level_comma(rest, pos + 1, depth - 1)

  defp find_top_level_comma(<<_, rest::binary>>, pos, depth),
    do: find_top_level_comma(rest, pos + 1, depth)

  defp skip_comment(<<>>, _pos, _depth), do: nil

  defp skip_comment(<<?\n, rest::binary>>, pos, depth),
    do: find_top_level_comma(rest, pos + 1, depth)

  defp skip_comment(<<_, rest::binary>>, pos, depth), do: skip_comment(rest, pos + 1, depth)

  defp skip_string(<<>>, _pos, _depth), do: nil

  defp skip_string(<<?\\, _, rest::binary>>, pos, depth), do: skip_string(rest, pos + 2, depth)

  defp skip_string(<<?", rest::binary>>, pos, depth),
    do: find_top_level_comma(rest, pos + 1, depth)

  defp skip_string(<<_, rest::binary>>, pos, depth), do: skip_string(rest, pos + 1, depth)

  # Sort key: the first dependency name outside comment lines, so a
  # commented-out dep above an entry doesn't hijack its position.
  defp entry_name(entry) do
    code =
      entry
      |> String.split("\n")
      |> Enum.reject(&String.match?(&1, ~r/^\s*#/))
      |> Enum.join("\n")

    case Regex.run(~r/\{:(\w+)/, code) do
      [_, name] -> name
      _ -> code
    end
  end
end
