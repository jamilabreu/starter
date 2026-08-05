defmodule Mix.Tasks.Starter.Gen.TailwindFormatter do
  @shortdoc "Generates a Tailwind class formatter"
  @moduledoc "Generates a formatter that sorts Tailwind CSS classes in HEEx templates."
  use Igniter.Mix.Task

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
    app_web_name = Helpers.app_web_module(igniter)

    value =
      Sourceror.parse_string!("""
      if Code.ensure_loaded?(#{app_web_name}.Formatters.ClassFormatter) do
        %{class: #{app_web_name}.Formatters.ClassFormatter}
      else
        %{}
      end
      """)

    Igniter.update_elixir_file(igniter, ".formatter.exs", fn zipper ->
      Igniter.Code.Keyword.set_keyword_key(zipper, :attribute_formatters, value, fn zipper ->
        {:ok, Sourceror.Zipper.replace(zipper, value)}
      end)
    end)
  end
end
