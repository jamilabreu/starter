defmodule Mix.Tasks.Starter.Remove.ThemeToggleTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  @root_layout """
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <script>
        (() => {
          const setTheme = (theme) => {
            localStorage.setItem("phx:theme", theme);
            document.documentElement.setAttribute("data-theme", theme);
          };
          window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));
        })();
      </script>
    </head>
    <body>
      {@inner_content}
    </body>
  </html>
  """

  @layouts """
  defmodule TestWeb.Layouts do
    use TestWeb, :html

    embed_templates "layouts/*"

    def app(assigns) do
      ~H\"\"\"
      <header class="navbar">
        <ul>
          <li>
            <a href="https://phoenixframework.org/">Website</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
        </ul>
      </header>
      <main>{render_slot(@inner_block)}</main>
      \"\"\"
    end

    @doc \"\"\"
    Provides dark vs light theme toggle based on themes defined in app.css.
    \"\"\"
    def theme_toggle(assigns) do
      ~H\"\"\"
      <div class="card">
        <button phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
          System
        </button>
      </div>
      \"\"\"
    end
  end
  """

  defp project_with_theme do
    test_project(
      files: %{
        "lib/test_web/components/layouts/root.html.heex" => @root_layout,
        "lib/test_web/components/layouts.ex" => @layouts
      }
    )
  end

  test "removes the theme script from the root layout" do
    igniter =
      project_with_theme()
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.ThemeToggle)

    diff = diff(igniter, only: "lib/test_web/components/layouts/root.html.heex")
    assert diff =~ "- |    <script>"
    refute diff =~ ~r/\+\s*\|.*setTheme/
  end

  test "removes the theme_toggle component and its wrapping <li>" do
    igniter =
      project_with_theme()
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.ThemeToggle)

    diff = diff(igniter, only: "lib/test_web/components/layouts.ex")
    assert diff =~ ~r/-\s*\|\s*def theme_toggle\(assigns\) do/
    assert diff =~ ~r/-\s*\|\s*<\.theme_toggle \/>/
    # The wrapping <li></li> goes with it
    refute diff =~ ~r/\+\s*\|\s*<li>\s*$/m
  end

  test "warns loudly when there is no theme toggle to remove" do
    igniter =
      test_project(
        files: %{
          "lib/test_web/components/layouts/root.html.heex" => "<html></html>\n",
          "lib/test_web/components/layouts.ex" => "defmodule TestWeb.Layouts do\nend\n"
        }
      )
      |> Igniter.compose_task(Mix.Tasks.Starter.Remove.ThemeToggle)

    assert Enum.any?(igniter.warnings, &(&1 =~ "no theme scripts were found"))
    assert Enum.any?(igniter.warnings, &(&1 =~ "no theme_toggle component was found"))
  end
end
