defmodule Mix.Tasks.Starter.Gen.TailwindFormatter do
  @shortdoc "Generates a Tailwind class formatter"
  @moduledoc "Generates a formatter that sorts Tailwind CSS classes in HEEx templates."
  use Igniter.Mix.Task

  alias Sourceror.Zipper
  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_formatter()
    |> add_formatter_config()
  end

  defp add_formatter(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_web_name = Helpers.app_web_module(igniter)
    path = "lib/#{app_name}_web/formatters/class_formatter.ex"

    content = """
    defmodule #{app_web_name}.Formatters.ClassFormatter do
      @moduledoc \"\"\"
      Sorts Tailwind CSS classes in HTML templates.

      Sorting rules:
      1. Sort classes alphabetically by base name (part after last `:`)
      2. Ignore negative prefixes (-) when sorting
      3. State classes (hover:, focus:, etc.) go at the end
      \"\"\"

      @state_keywords MapSet.new(
                        ~w(hover focus active disabled visited first last odd even group-hover peer-hover focus-within focus-visible)
                      )

      @doc \"\"\"
      Called by Phoenix.LiveView.HTMLFormatter to format the class attribute.
      \"\"\"
      def render_attribute({name, {:string, value, meta}, attr_meta}, _opts) do
        sorted = sort_classes(value)
        {name, {:string, sorted, meta}, attr_meta}
      end

      def render_attribute(attr, _opts), do: attr

      defp sort_classes(value) do
        value
        |> String.split()
        |> Enum.sort_by(&sort_key/1)
        |> Enum.join(" ")
      end

      defp sort_key(class) do
        parts = :binary.split(class, ":", [:global])
        base = parts |> List.last() |> String.trim_leading("-")
        priority = if has_state_prefix?(parts), do: 1, else: 0
        {priority, base}
      end

      defp has_state_prefix?([_single]), do: false

      defp has_state_prefix?(parts) do
        parts |> Enum.drop(-1) |> Enum.any?(&MapSet.member?(@state_keywords, &1))
      end
    end
    """

    Igniter.create_new_file(igniter, path, content)
  end

  defp add_formatter_config(igniter) do
    app_name = Igniter.Project.Application.app_name(igniter)
    app_web_name = Helpers.app_web_module(igniter)
    path = "lib/#{app_name}_web/formatters/class_formatter.ex"

    value = Sourceror.parse_string!("%{class: #{app_web_name}.Formatters.ClassFormatter}")

    igniter
    |> Igniter.update_elixir_file(".formatter.exs", fn zipper ->
      zipper
      |> config_list()
      |> Igniter.Code.Keyword.set_keyword_key(:attribute_formatters, value, fn zipper ->
        {:ok, Zipper.replace(zipper, value)}
      end)
    end)
    |> Igniter.update_elixir_file(".formatter.exs", fn zipper ->
      {:ok, require_formatter(zipper, path, "#{app_web_name}.Formatters.ClassFormatter")}
    end)
  end

  # Once the require is in place the file is a two-statement block, so the
  # config itself is the last expression rather than the whole file.
  defp config_list(zipper) do
    case Zipper.node(zipper) do
      {:__block__, _meta, children} when length(children) > 1 ->
        zipper |> Zipper.down() |> Zipper.rightmost()

      _node ->
        zipper
    end
  end

  # `.formatter.exs` is read before the project's code paths are set up, so a
  # module of the app's is not loadable from it — not even after `mix compile`.
  # Requiring the source directly is what makes the class formatter run at all,
  # and it makes formatting identical whether or not the app is built.
  defp require_formatter(zipper, path, module) do
    # Two conditions, each earning its place: the file check keeps the run
    # alive while the formatter source is still pending, and the loaded check
    # avoids redefining the module during tasks that have already built the
    # app. Plain `mix format` satisfies neither, which is the case that needs
    # the require.
    call =
      Sourceror.parse_string!("""
      if File.exists?("#{path}") and not Code.ensure_loaded?(#{module}),
        do: Code.require_file("#{path}")\
      """)

    top = Zipper.topmost(zipper)

    case Zipper.node(top) do
      {:__block__, meta, children} = node when is_list(children) ->
        if requires_file?(node, path) do
          top
        else
          Zipper.replace(top, {:__block__, meta, [call | children]})
        end

      node ->
        Zipper.replace(top, {:__block__, [], [call, node]})
    end
  end

  defp requires_file?(node, path) do
    {_node, found?} =
      Macro.prewalk(node, false, fn
        {{:., _, [{:__aliases__, _, [:Code]}, :require_file]}, _, _} = call, _acc ->
          {call, Macro.to_string(call) =~ path}

        other, acc ->
          {other, acc}
      end)

    found?
  end
end
