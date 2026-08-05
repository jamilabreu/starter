defmodule Mix.Tasks.Starter.Gen.MinimalAppLayout do
  @shortdoc "Generates a minimal app layout"
  @moduledoc "Replaces the `Layouts.app/1` component with a minimal header-and-main layout."
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_name = Helpers.app_module(igniter)
    layouts_module = Module.concat([Helpers.app_web_module(igniter), "Layouts"])

    new_app_fn = app_function_ast(app_name)

    Igniter.Project.Module.find_and_update_module!(igniter, layouts_module, fn zipper ->
      case move_to_def_node(zipper, :app) do
        {:ok, zipper} ->
          {:ok, Sourceror.Zipper.replace(zipper, new_app_fn)}

        :error ->
          {:warning,
           "#{inspect(layouts_module)} has no app/1 function — skipped generating the " <>
             "minimal app layout. Either it was customized, or phx.new's output has changed."}
      end
    end)
  end

  defp move_to_def_node(zipper, name) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      match?({:def, _, [{^name, _, _} | _]}, Sourceror.Zipper.node(z))
    end)
  end

  defp app_function_ast(app_name) do
    """
    def app(assigns) do
      ~H\"\"\"
      <header class="flex gap-4 items-center px-4 py-3">
        <a href="/" class="font-semibold">#{app_name}</a>
        <div class="flex-1"></div>
        <.button class="bg-black font-semibold h-8 px-4 rounded text-sm text-white">
          Primary Action
        </.button>
      </header>
      <main>
        {render_slot(@inner_block)}
      </main>
      <.flash_group flash={@flash} />
      \"\"\"
    end
    """
    |> Sourceror.parse_string!()
  end
end
