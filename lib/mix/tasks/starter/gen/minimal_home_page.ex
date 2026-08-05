defmodule Mix.Tasks.Starter.Gen.MinimalHomePage do
  @shortdoc "Generates a minimal home page"
  @moduledoc """
  Replaces the `phx.new` marketing home page with a minimal starting point.

  Note: this overwrites `home.html.heex` — intended for freshly generated apps.
  """
  use Igniter.Mix.Task

  alias Starter.Helpers

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()
    path = "lib/#{app_web}/controllers/page_html/home.html.heex"

    content = """
    <Layouts.app flash={@flash}>
      <div class="flex justify-center">
        <div class="bg-gray-100 px-20 py-16">Home Page</div>
      </div>
    </Layouts.app>
    """

    if Igniter.exists?(igniter, path) do
      Igniter.update_file(igniter, path, fn source ->
        Rewrite.Source.update(source, :content, content)
      end)
    else
      Igniter.add_warning(
        igniter,
        "#{path} not found — skipped generating the home page. " <>
          "Either the page controller was removed, or phx.new's output has changed."
      )
    end
  end
end
