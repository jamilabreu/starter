defmodule Mix.Tasks.Starter.Add.Remixicons do
  @shortdoc "Adds Remix Icons"
  @moduledoc ~S(Adds Remix Icons as a Tailwind plugin with `remix-#{ICON}` classes.)
  use Igniter.Mix.Task

  alias Starter.Helpers
  alias Starter.Versions

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    igniter
    |> add_dep()
    |> create_plugin()
    |> update_app_css()
    |> add_icon_function()
  end

  defp add_dep(igniter) do
    tag = Versions.fetch_github_tag("Remix-Design", "RemixIcon") || "v4.8.0"

    Igniter.Project.Deps.add_dep(igniter, {
      :remixicons,
      github: "Remix-Design/RemixIcon",
      tag: tag,
      sparse: "icons",
      app: false,
      compile: false,
      depth: 1
    })
  end

  defp create_plugin(igniter) do
    content = """
    const plugin = require("tailwindcss/plugin");
    const fs = require("fs");
    const path = require("path");

    module.exports = plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../../deps/remixicons/icons");
      let values = {};

      // Read all category directories
      fs.readdirSync(iconsDir).forEach((category) => {
        let categoryPath = path.join(iconsDir, category);
        if (fs.statSync(categoryPath).isDirectory()) {
          fs.readdirSync(categoryPath).forEach((file) => {
            if (file.endsWith(".svg")) {
              let name = path.basename(file, ".svg");
              let fullPath = path.join(categoryPath, file);
              values[name] = { name, fullPath };
              // Make -line variant the default (e.g., "search" maps to "search-line")
              if (name.endsWith("-line")) {
                let baseName = name.slice(0, -5);
                values[baseName] = { name: baseName, fullPath };
              }
            }
          });
        }
      });

      matchComponents(
        {
          remix: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\\r?\\n|\\r/g, "");
            content = encodeURIComponent(content);
            let size = theme("spacing.4");
            return {
              [`--remix-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--remix-${name})`,
              mask: `var(--remix-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: size,
              height: size,
            };
          },
        },
        { values },
      );
    });
    """

    Igniter.create_new_file(igniter, "assets/vendor/remixicons.js", content)
  end

  defp update_app_css(igniter) do
    plugin_import =
      """
      /* A Tailwind plugin that makes "remix-\#{ICON}" classes available.
         The remixicon installation itself is managed by your mix.exs */
      @plugin "../vendor/remixicons";
      """

    Helpers.update_file_checked(
      igniter,
      "assets/css/app.css",
      fn content ->
        String.replace(
          content,
          ~s|@plugin "../vendor/heroicons";\n|,
          ~s|@plugin "../vendor/heroicons";\n\n| <> plugin_import
        )
      end,
      "could not find the heroicons plugin line in assets/css/app.css to anchor " <>
        "the remixicons plugin. Add `@plugin \"../vendor/remixicons\";` manually."
    )
  end

  defp add_icon_function(igniter) do
    app_web_module = Helpers.app_web_module(igniter)
    core_components_module = Module.concat([app_web_module, "CoreComponents"])

    remix_icon_code = ~S'''
    def icon(%{name: "remix-" <> _} = assigns) do
      ~H"""
      <span class={[@name, @class]} />
      """
    end
    '''

    Igniter.Project.Module.find_and_update_module!(igniter, core_components_module, fn zipper ->
      case move_to_hero_icon_function(zipper) do
        {:ok, zipper} ->
          {:ok, Sourceror.Zipper.insert_right(zipper, Sourceror.parse_string!(remix_icon_code))}

        :error ->
          {:ok, Igniter.Code.Common.add_code(zipper, remix_icon_code)}
      end
    end)
  end

  defp move_to_hero_icon_function(zipper) do
    Igniter.Code.Common.move_to(zipper, fn z ->
      match?({:def, _, [{:icon, _, _} | _]}, Sourceror.Zipper.node(z))
    end)
  end
end
