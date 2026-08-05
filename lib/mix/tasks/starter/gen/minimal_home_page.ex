defmodule Mix.Tasks.Starter.Gen.MinimalHomePage do
  @shortdoc "Generates a minimal home page"
  @moduledoc """
  Replaces the `phx.new` marketing home page with a minimal starting point,
  and updates the generated page controller test to match.

  Note: this overwrites `home.html.heex` — intended for freshly generated apps.
  """
  use Igniter.Mix.Task

  alias Starter.Helpers

  @marketing_copy "Peace of mind from prototype to production"

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app_web = Helpers.app_web_module(igniter) |> Macro.underscore()

    igniter
    |> replace_home_page(app_web)
    |> update_page_test(app_web)
  end

  defp replace_home_page(igniter, app_web) do
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

  # phx.new's page controller test asserts the marketing copy; point it at
  # the new page so the app's tests still pass after the replacement.
  defp update_page_test(igniter, app_web) do
    path = "test/#{app_web}/controllers/page_controller_test.exs"

    if Igniter.exists?(igniter, path) do
      Helpers.update_file_content(igniter, path, fn content ->
        String.replace(content, inspect(@marketing_copy), inspect("Home Page"))
      end)
    else
      igniter
    end
  end
end
